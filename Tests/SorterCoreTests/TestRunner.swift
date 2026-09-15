import Foundation
var failures: [String] = []
func XCTFail(_ text: String, file: StaticString = #filePath, line: UInt = #line) { failures.append("\(file):\(line): \(text)"); print("FAIL: \(text)") }
func XCTAssertTrue(_ value: @autoclosure () throws -> Bool, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
    do { if try !value() { XCTFail("Expected true. \(message)", file: file, line: line) } } catch { XCTFail("\(error)", file: file, line: line) }
}
func XCTAssertFalse(_ value: @autoclosure () throws -> Bool, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) {
    do { if try value() { XCTFail("Expected false. \(message)", file: file, line: line) } } catch { XCTFail("\(error)", file: file, line: line) }
}
func XCTAssertEqual<T: Equatable>(_ lhs: @autoclosure () throws -> T, _ rhs: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line) {
    do { let a = try lhs(), b = try rhs(); if a != b { XCTFail("\(a) != \(b)", file: file, line: line) } } catch { XCTFail("\(error)", file: file, line: line) }
}
func XCTAssertNotEqual<T: Equatable>(_ lhs: @autoclosure () throws -> T, _ rhs: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line) {
    do { if try lhs() == rhs() { XCTFail("Values unexpectedly equal", file: file, line: line) } } catch { XCTFail("\(error)", file: file, line: line) }
}
func XCTAssertGreaterThan<T: Comparable>(_ lhs: @autoclosure () throws -> T, _ rhs: T, file: StaticString = #filePath, line: UInt = #line) {
    do { if try lhs() <= rhs { XCTFail("Expected greater than \(rhs)", file: file, line: line) } } catch { XCTFail("\(error)", file: file, line: line) }
}
func XCTAssertNotNil<T>(_ value: T?, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) { if value == nil { XCTFail("Unexpected nil. \(message)", file: file, line: line) } }
func XCTAssertThrowsError<T>(_ body: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line) { do { _ = try body(); XCTFail("Expected an error", file: file, line: line) } catch {} }
func XCTAssertNoThrow<T>(_ body: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line) { do { _ = try body() } catch { XCTFail("\(error)", file: file, line: line) } }
func XCTUnwrap<T>(_ value: T?) throws -> T { guard let value else { throw NSError(domain: "Unwrap", code: 1) }; return value }

@main struct TestRunner {
    static func main() async {
        let suite = SafetyTests()
        let tests: [(String, () async throws -> Void)] = [
            ("approval and destination collision", { try await suite.testMoveRequiresApprovalAndDoesNotOverwrite() }),
            ("undo with original collision", { try await suite.testUndoWithOriginalConflictPreservesBothFiles() }),
            ("undo rejects modified files", { try await suite.testUndoRefusesModifiedFile() }),
            ("stale preview", { try await suite.testStalePreviewRefused() }),
            ("download stability and writer detection", { try suite.testDownloadStabilityAndOpenWriter() }),
            ("hidden/temp/link/alias/bundle/destination skips", { try suite.testSkipUnsafeAndDestination() }),
            ("configuration traversal and name validation", { try suite.testConfigurationRejectsTraversalAndDuplicateNames() }),
            ("write-ahead crash recovery and process lock", { try suite.testWriteAheadRecoveryAndJournalLock() }),
            ("interrupted move and undo recovery", { try await suite.testRecoveryBeforeRenameAndInterruptedUndo() }),
            ("corrupt history fails closed", { try suite.testCorruptJournalFailsClosed() }),
            ("rules, AI-disabled fallback and injection", { try await suite.testRulesAndAIDisabledFallback() }),
            ("read-only preview and automation baseline", { try await suite.testPreviewNeverMovesAndExcludesBaseline() }),
            ("DOCX/XLSX/PPTX/RTF local extraction", { try suite.testLocalOfficeExtraction() }),
            ("scanned PDF Vision OCR", { try suite.testScannedPDFUsesVisionOCR() }),
            ("destination symlink and kernel no-replace", { try await suite.testDestinationSymlinkAndKernelNoReplace() }),
            ("native PDF / DOC / ODT local extraction", { try suite.testNativePDFAndLegacyOfficeExtraction() }),
            ("extraction limits and subprocess timeout", { try await suite.testExtractionLimitsAndTimeout() }),
            ("persistent arrivals, automatic fallback, pause and undo", { try await suite.testPersistentArrivalsAndAutomaticFallback() }),
            ("original edits, same-name new download and corrupt automation state", { try suite.testOriginalEditsAndNewSameName() })
        ]
        for (name, test) in tests {
            let before = failures.count
            do { try await test() } catch { XCTFail("\(name): \(error.localizedDescription)") }
            print("\(failures.count == before ? "PASS" : "FAIL") \(name)")
        }
        print("Safety suites: \(tests.count), assertion failures: \(failures.count)")
        for failure in failures { print(failure) }
        exit(failures.isEmpty ? 0 : 1)
    }
}
