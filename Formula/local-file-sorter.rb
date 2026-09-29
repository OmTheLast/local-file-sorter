class LocalFileSorter < Formula
  desc "Sort downloads using rules and on-device Apple Intelligence"
  homepage "https://github.com/OmTheLast/local-file-sorter"
  url "https://github.com/OmTheLast/local-file-sorter/releases/download/v0.4.0/LocalFileSorter-0.4.0-source.tar.gz"
  sha256 "262928e48786118a0b2469f35c566191a4e8abf222bb5fdd510031d96269797f"

  depends_on arch: :arm64
  depends_on macos: :tahoe

  uses_from_macos "swift" => :build

  def install
    system "./scripts/build-app.sh", "--homebrew", "--no-samples"
    libexec.install "dist/Local File Sorter.app"
    (bin/"local-file-sorter").write <<~SH
      #!/bin/sh
      app="#{opt_libexec}/Local File Sorter.app"
      case "${1:-}" in
        --version) exec /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist" ;;
        --path) printf '%s\\n' "$app" ;;
        --demo) exec /usr/bin/open -n "$app" --args --demo ;;
        --background) exec /usr/bin/open -g "$app" --args --background ;;
        '') exec /usr/bin/open "$app" ;;
        *) printf '%s\\n' 'Usage: local-file-sorter [--version|--path|--demo|--background]' >&2; exit 2 ;;
      esac
    SH
  end

  def caveats
    <<~EOS
      Run local-file-sorter to choose folders and review existing documents.
      Enable automatic sorting in setup for new browser downloads.
      For login startup, add the path printed by local-file-sorter --path
      to System Settings > General > Login Items.
      Quit the app before upgrading or uninstalling. Settings, sorted files
      and undo history are preserved. Run local-file-sorter after upgrading.
    EOS
  end

  test do
    assert_equal version.to_s, shell_output("#{bin}/local-file-sorter --version").strip
    app = libexec/"Local File Sorter.app"
    assert_path_exists app/"Contents/MacOS/LocalFileSorter"
    system "/usr/bin/codesign", "--verify", "--deep", "--strict", app
    assert_equal "arm64", shell_output("/usr/bin/lipo -archs '#{app}/Contents/MacOS/LocalFileSorter'").strip
  end
end
