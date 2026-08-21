//
//  PortService.swift
//  Meow
//
//  端口诊断：扫描本机正在监听的 TCP/UDP 端口，支持实时刷新与结束进程。
//

import AppKit
import Darwin
import Foundation

// MARK: - 端口条目

/// 一个正在监听的端口及其占用进程
struct PortEntry: Identifiable, Hashable {
    /// 唯一标识（同一进程同一端口可能监听多个地址）
    let id: String
    /// 端口号
    let port: Int
    /// 协议：TCP / UDP
    let proto: String
    /// 进程名
    let processName: String
    /// 进程 PID
    let pid: Int32
    /// 所属用户
    let user: String
    /// 进程可执行文件路径
    let processPath: String
    /// 监听地址列表（如 `*`、`127.0.0.1`、`[::]`）
    var addresses: [String]

    /// 搜索匹配文本
    var searchText: String {
        "\(port) \(processName) \(pid) \(user) \(addresses.joined(separator: " "))"
    }
}

// MARK: - 端口分组

/// 按应用分组的端口集合（同一 `.app` bundle 的多个进程合并为一组）
struct PortGroup: Identifiable {
    /// 分组 key：`bundle:<路径>` 或 `pid:<PID>`
    let id: String
    /// 组显示名（应用本地化名称或进程名）
    let appName: String
    /// 应用图标
    let icon: NSImage?
    /// 组内第一个条目的进程路径
    let processPath: String?
    /// 组内涉及的所有 PID
    let pids: [Int32]
    /// 组内端口（按端口号升序）
    let ports: [PortEntry]

    var portCount: Int { ports.count }
}

// MARK: - 错误类型

enum PortServiceError: LocalizedError {
    case commandFailed(String)
    case processNotFound(pid: Int32)
    case permissionDenied(pid: Int32, name: String)
    case killFailed(pid: Int32, message: String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return "扫描端口失败：\(message)"
        case .processNotFound(let pid):
            return "进程 \(pid) 已不存在，可能已自行退出"
        case .permissionDenied(let pid, let name):
            return "没有权限结束进程 \(name)（PID \(pid)）。该进程可能属于其他用户，请在终端中使用 `sudo kill -9 \(pid)` 结束。"
        case .killFailed(let pid, let message):
            return "结束进程 \(pid) 失败：\(message)"
        }
    }
}

// MARK: - lsof 解析中间结构

/// lsof -F 输出中的一个 socket 记录
private struct RawSocket {
    let pid: Int32
    let processName: String
    let user: String
    let proto: String
    let address: String
    let port: Int
}

// MARK: - 端口服务

/// 端口扫描服务：基于 `lsof` 扫描监听端口，基于 `ps` 解析进程路径
enum PortService {

    // MARK: 扫描

    /// 扫描当前所有监听中的 TCP/UDP 端口（按端口号升序）
    static func fetchListeningPorts() async throws -> [PortEntry] {
        let tcp = try runLsof(args: ["-nP", "-iTCP", "-sTCP:LISTEN", "-F", "pcuPn"])
        let udp = try runLsof(args: ["-nP", "-iUDP", "-F", "pcuPn"])
        let raw = parseLsofOutput(tcp + udp)
        guard !raw.isEmpty else { return [] }

        // 批量获取进程路径
        let paths = fetchProcessPaths(pids: Set(raw.map(\.pid)))

        // 按 (pid, port, proto) 合并多个监听地址（如 IPv4 + IPv6 双栈）
        var merged: [String: PortEntry] = [:]
        for socket in raw {
            let key = "\(socket.pid)-\(socket.port)-\(socket.proto)"
            if var entry = merged[key] {
                if !entry.addresses.contains(socket.address) {
                    entry.addresses.append(socket.address)
                    merged[key] = entry
                }
            } else {
                merged[key] = PortEntry(
                    id: key,
                    port: socket.port,
                    proto: socket.proto,
                    processName: socket.processName,
                    pid: socket.pid,
                    user: socket.user,
                    processPath: paths[socket.pid] ?? "",
                    addresses: [socket.address]
                )
            }
        }

        return merged.values.sorted {
            $0.port != $1.port ? $0.port < $1.port : $0.pid < $1.pid
        }
    }

    // MARK: - 应用图标

    /// 获取占用端口进程对应的应用图标：
    /// 1. 运行中的 GUI 应用 → 按 PID 取真实图标（NSRunningApplication）
    /// 2. 可执行文件在 .app bundle 内 → 反查 bundle 图标
    /// 3. 其余（命令行 / 守护进程）→ 文件类型通用图标
    static func icon(for entry: PortEntry) -> NSImage? {
        if let app = NSRunningApplication(processIdentifier: entry.pid),
           let icon = app.icon {
            return icon
        }
        guard entry.processPath.hasPrefix("/") else { return nil }
        if let bundlePath = appBundlePath(from: entry.processPath) {
            return NSWorkspace.shared.icon(forFile: bundlePath)
        }
        return NSWorkspace.shared.icon(forFile: entry.processPath)
    }

    /// 从可执行文件路径提取 .app bundle 路径
    /// 如 `/Applications/Kando.app/Contents/MacOS/Kando` → `/Applications/Kando.app`
    private static func appBundlePath(from executablePath: String) -> String? {
        guard let range = executablePath.range(of: ".app/") else { return nil }
        let endIndex = executablePath.index(range.lowerBound, offsetBy: 4) // ".app" 长度
        return String(executablePath[..<endIndex])
    }

    // MARK: - 应用分组

    /// 将端口条目按应用分组：优先按 `.app` bundle 合并（同一应用的多进程、多端口归为一组，
    /// 如 OrbStack 占用的十几个端口），无 bundle 的进程按 PID 分组。
    /// 组按端口数降序排列（占端口多的应用在前），组内按端口号升序。
    static func groupPorts(_ entries: [PortEntry]) -> [PortGroup] {
        var buckets: [String: (appName: String, icon: NSImage?, path: String?, pids: Set<Int32>, ports: [PortEntry])] = [:]

        for entry in entries {
            let key: String
            let appName: String
            if let bundle = appBundlePath(from: entry.processPath) {
                key = "bundle:\(bundle)"
                appName = bundleName(from: bundle, pid: entry.pid)
            } else {
                key = "pid:\(entry.pid)"
                appName = entry.processName
            }

            var bucket = buckets[key] ?? (appName, nil, nil, [], [])
            if bucket.icon == nil { bucket.icon = icon(for: entry) }
            if bucket.path == nil { bucket.path = entry.processPath }
            bucket.pids.insert(entry.pid)
            bucket.ports.append(entry)
            buckets[key] = bucket
        }

        return buckets.map { key, bucket in
            PortGroup(
                id: key,
                appName: bucket.appName,
                icon: bucket.icon,
                processPath: bucket.path,
                pids: bucket.pids.sorted(),
                ports: bucket.ports.sorted { $0.port < $1.port }
            )
        }
        .sorted {
            if $0.ports.count != $1.ports.count { return $0.ports.count > $1.ports.count }
            return $0.appName.localizedStandardCompare($1.appName) == .orderedAscending
        }
    }

    /// 从 bundle 路径取应用显示名（优先本地化名称，回退 bundle 文件名）
    private static func bundleName(from bundlePath: String, pid: Int32) -> String {
        if let name = NSRunningApplication(processIdentifier: pid)?.localizedName, !name.isEmpty {
            return name
        }
        let fileName = (bundlePath as NSString).lastPathComponent
        return fileName.replacingOccurrences(of: ".app", with: "")
    }

    // MARK: 杀进程

    /// 结束指定 PID 的进程（SIGKILL）
    @discardableResult
    static func killProcess(pid: Int32) throws -> Bool {
        guard pid > 1 else {
            throw PortServiceError.killFailed(pid: pid, message: "不允许结束系统核心进程")
        }
        let result = Darwin.kill(pid, SIGKILL)
        guard result != 0 else { return true }

        let errorCode = errno
        switch errorCode {
        case ESRCH:
            throw PortServiceError.processNotFound(pid: pid)
        case EPERM:
            throw PortServiceError.permissionDenied(pid: pid, name: processName(for: pid))
        default:
            throw PortServiceError.killFailed(pid: pid, message: String(cString: strerror(errorCode)))
        }
    }

    // MARK: - 命令执行

    /// 执行 lsof 并返回原始输出（无匹配时 lsof 退出码为 1，属正常情况，故不抛错）
    private static func runLsof(args: [String]) throws -> String {
        try runCommand("/usr/sbin/lsof", args)
    }

    private static func runCommand(_ executablePath: String, _ args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            throw PortServiceError.commandFailed("无法执行 \(executablePath)：\(error.localizedDescription)")
        }
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - 输出解析

    /// 解析 `lsof -F pcuPn` 输出（字段行以首字符区分，`f` 等未请求字段自动忽略）
    private static func parseLsofOutput(_ output: String) -> [RawSocket] {
        var sockets: [RawSocket] = []
        var current: (pid: Int32, command: String, user: String, proto: String)?

        for line in output.split(separator: "\n") {
            let text = String(line)
            guard let first = text.first else { continue }
            let value = String(text.dropFirst())

            switch first {
            case "p":
                if let pid = Int32(value) {
                    current = (pid, "", "", "")
                }
            case "c":
                current?.command = value
            case "u":
                current?.user = value
            case "P":
                current?.proto = value.uppercased()
            case "n":
                guard let info = current,
                      let parsed = parseName(value) else { continue }
                sockets.append(RawSocket(
                    pid: info.pid,
                    processName: info.command,
                    user: info.user,
                    proto: info.proto.isEmpty ? "TCP" : info.proto,
                    address: parsed.address,
                    port: parsed.port
                ))
            default:
                break
            }
        }
        return sockets
    }

    /// 从 lsof 的 NAME 字段解析地址与端口，如 `*:8080`、`[::]:3000`、
    /// `127.0.0.1:6379->127.0.0.1:6379`；端口为 `*` 的行（UDP 端口 0）返回 nil
    private static func parseName(_ raw: String) -> (address: String, port: Int)? {
        var name = raw
        // 去掉状态后缀（如 " (LISTEN)"）
        if let range = name.range(of: " (") { name = String(name[..<range.lowerBound]) }
        // 只保留本地地址部分（UDP 可能带 ->remote）
        if let arrow = name.range(of: "->") { name = String(name[..<arrow.lowerBound]) }
        guard let colon = name.lastIndex(of: ":") else { return nil }
        let portPart = name[name.index(after: colon)...]
        guard let port = Int(portPart) else { return nil }
        return (String(name[..<colon]), port)
    }

    /// 批量查询进程可执行文件路径（`ps -o comm=`，一次调用）
    private static func fetchProcessPaths(pids: Set<Int32>) -> [Int32: String] {
        guard !pids.isEmpty else { return [:] }
        let pidList = pids.sorted().map(String.init).joined(separator: ",")
        let output = (try? runCommand("/bin/ps", ["-p", pidList, "-o", "pid=,comm="])) ?? ""
        var paths: [Int32: String] = [:]
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2, let pid = Int32(parts[0]) else { continue }
            var path = String(parts[1]).trimmingCharacters(in: .whitespaces)
            // 去掉 ps 对含空格路径添加的引号
            if path.hasPrefix("\""), path.hasSuffix("\"") {
                path = String(path.dropFirst().dropLast())
            }
            paths[pid] = path
        }
        return paths
    }

    /// 查询单个进程名（用于错误提示）
    private static func processName(for pid: Int32) -> String {
        let output = (try? runCommand("/bin/ps", ["-p", String(pid), "-o", "comm="])) ?? ""
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
