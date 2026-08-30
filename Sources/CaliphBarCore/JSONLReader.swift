import Foundation

enum JSONLReader {
    static func forEachLine(at url: URL, chunkSize: Int = 64 * 1024, body: (Data) -> Void) throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var buffer = Data()
        while true {
            let chunk = try handle.read(upToCount: chunkSize) ?? Data()
            if chunk.isEmpty { break }
            buffer.append(chunk)

            while let newline = buffer.firstIndex(of: 0x0A) {
                let line = buffer[..<newline]
                if !line.isEmpty { body(Data(line)) }
                buffer.removeSubrange(...newline)
            }
        }

        if !buffer.isEmpty { body(buffer) }
    }
}
