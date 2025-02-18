class Qwt < Formula
  desc "Qt Widgets for Technical Applications"
  homepage "https://qwt.sourceforge.io/"
  url "https://downloads.sourceforge.net/project/qwt/qwt/6.2.0/qwt-6.2.0.tar.bz2"
  sha256 "9194f6513955d0fd7300f67158175064460197abab1a92fa127a67a4b0b71530"
  license "LGPL-2.1-only" => { with: "Qwt-exception-1.0" }

  livecheck do
    url :stable
    regex(%r{url=.*?/qwt[._-]v?(\d+(?:\.\d+)+)\.t}i)
  end

  bottle do
    sha256 cellar: :any,                 arm64_big_sur: "0538bfe404c21c264efe57fbc36d3cff81c39b86679d67c48501166597ab8cad"
    sha256 cellar: :any,                 big_sur:       "14a5fd16a5abcf3a04b3f6d097649fbc1dd51e9fbb50d05f885757a9d9f3d9f9"
    sha256 cellar: :any,                 catalina:      "c3a727be657b20efdd6a8ddec980bd28f5367ae41a0a7abefb74af86c1f24e83"
    sha256 cellar: :any,                 mojave:        "5bb62a4122ade6485247357b22f0619ff35f518d9ea3f454f05c7d5c4b60985e"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "bd8a743a4dcdef47dd5941eba2feb9f5db4f9a63588ebf97c8ebe36d4c7814e4"
  end

  depends_on "qt@5"

  on_linux do
    depends_on "gcc"
  end

  fails_with gcc: "5"

  # Update designer plugin linking back to qwt framework/lib after install
  # See: https://sourceforge.net/p/qwt/patches/45/
  patch :DATA

  def install
    inreplace "qwtconfig.pri" do |s|
      s.gsub!(/^\s*QWT_INSTALL_PREFIX\s*=(.*)$/, "QWT_INSTALL_PREFIX=#{prefix}")

      # Install Qt plugin in `lib/qt/plugins/designer`, not `plugins/designer`.
      s.sub! %r{(= \$\$\{QWT_INSTALL_PREFIX\})/(plugins/designer)$},
             "\\1/lib/qt/\\2"
    end

    args = ["-config", "release", "-spec"]
    spec = if ENV.compiler == :clang
      "macx-clang"
    else
      "macx-g++"
    end
    on_linux do
      spec = "linux-g++"
    end
    spec << "-arm64" if Hardware::CPU.arm?
    args << spec

    qt5 = Formula["qt@5"].opt_prefix
    system "#{qt5}/bin/qmake", *args
    system "make"
    system "make", "install"
  end

  test do
    (testpath/"test.cpp").write <<~EOS
      #include <qwt_plot_curve.h>
      int main() {
        QwtPlotCurve *curve1 = new QwtPlotCurve("Curve 1");
        return (curve1 == NULL);
      }
    EOS
    on_macos do
      system ENV.cxx, "test.cpp", "-o", "out",
        "-std=c++11",
        "-framework", "qwt", "-framework", "QtCore",
        "-F#{lib}", "-F#{Formula["qt@5"].opt_lib}",
        "-I#{lib}/qwt.framework/Headers",
        "-I#{Formula["qt@5"].opt_lib}/QtCore.framework/Versions/5/Headers",
        "-I#{Formula["qt@5"].opt_lib}/QtGui.framework/Versions/5/Headers"
    end
    on_linux do
      system ENV.cxx,
        "-I#{Formula["qt@5"].opt_include}",
        "-I#{Formula["qt@5"].opt_include}/QtCore",
        "-I#{Formula["qt@5"].opt_include}/QtGui",
        "test.cpp",
        "-lqwt", "-lQt5Core", "-lQt5Gui",
        "-L#{Formula["qt@5"].opt_lib}",
        "-L#{Formula["qwt"].opt_lib}",
        "-Wl,-rpath=#{Formula["qt@5"].opt_lib}",
        "-Wl,-rpath=#{Formula["qwt"].opt_lib}",
        "-o", "out", "-std=c++11", "-fPIC"
    end
    system "./out"
  end
end

__END__
diff --git a/designer/designer.pro b/designer/designer.pro
index c269e9d..c2e07ae 100644
--- a/designer/designer.pro
+++ b/designer/designer.pro
@@ -126,6 +126,16 @@ contains(QWT_CONFIG, QwtDesigner) {

     target.path = $${QWT_INSTALL_PLUGINS}
     INSTALLS += target
+
+    macx {
+        contains(QWT_CONFIG, QwtFramework) {
+            QWT_LIB = qwt.framework/Versions/$${QWT_VER_MAJ}/qwt
+        }
+        else {
+            QWT_LIB = libqwt.$${QWT_VER_MAJ}.dylib
+        }
+        QMAKE_POST_LINK = install_name_tool -change $${QWT_LIB} $${QWT_INSTALL_LIBS}/$${QWT_LIB} $(DESTDIR)$(TARGET)
+    }
 }
 else {
     TEMPLATE        = subdirs # do nothing
