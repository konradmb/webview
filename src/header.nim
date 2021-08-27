import nimterop/[build, cimport]
import strutils, sequtils, strformat, regex, os

proc getPkgconfigDirs(pkgconfigOutput: static string): static seq[string] =
  for m in pkgconfigOutput.findAll(re"-I([^ ]+)"):
    result.add m.group(0, pkgconfigOutput)

func getAlternateNames(s: openArray[string]): string =
  s.mapIt(fmt"/alternatename:WINRT_IMPL_{it}={it}").join(" ")
  
cDefine("WEBVIEW_API", "extern inline")

when defined(linux):
  discard
  {.passL: staticExec"pkg-config --libs gtk+-3.0 webkit2gtk-4.0".}
  const pkgconfigFlags = 
    staticExec("pkg-config --cflags gtk+-3.0 webkit2gtk-4.0").
      replace("-pthread", "")
  cIncludeDir(pkgconfigFlags.getPkgconfigDirs())
  # {.passC: staticExec"pkg-config --cflags gtk+-3.0 webkit2gtk-4.0".}
elif defined(windows):
  when not defined(vcc):
    {.fatal: """Webview on Windows requires MSVC compiler! Add "--cc:vcc" to nim arguments.""".}
  # const tmp = "--std=c++20 -mwindows -L./dll/x64 -lwebview -lWebView2Loader -I" & currentSourcePath.parentDir
  # const tmp2 = "\"" & tmp & "\""
  # cPassL(tmp2)
  # {.passL: .}
  {.passC: "/std:c++17".}
  # {.passC: """"/IC:\Program Files (x86)\Windows Kits\10\Include\10.0.19041.0\cppwinrt\winrt\base.h"""".}
  # {.passL: "/I" & currentSourcePath.parentDir/../"webview"/"script"/"microsoft.web.webview2.1.0.664.37"/"build"/"native"/"include".}
  # {.passL: "/link " & currentSourcePath.parentDir/../"webview"/"script"/"microsoft.web.webview2.1.0.664.37"/"build"/"native"/"x64"/"WebView2LoaderStatic.lib".}
  const linkLibs = 
    [
      currentSourcePath.parentDir/../"webview"/"script"/"microsoft.web.webview2.1.0.664.37"/"build"/"native"/"x64"/"WebView2LoaderStatic.lib",
      # """"C:\Program Files (x86)\Windows Kits\10\Lib\10.0.19041.0\um\x64\WindowsApp.lib"""",
      "version.lib", "WindowsApp.lib", "Shell32.lib"
      # "ole32.lib", "oleaut32.lib", "Kernel32.lib", , "OleAut32.lib", "user32.lib"
    ]
  const alternates = 
    [
      "LoadLibraryW", "FreeLibrary", "GetProcAddress", "SetErrorInfo", "GetErrorInfo", "CoInitializeEx", "CoCreateFreeThreadedMarshaler", "CoTaskMemAlloc", "SysAllocString", "SysFreeString", "SysStringLen", "MultiByteToWideChar", "WideCharToMultiByte", "HeapAlloc", "HeapFree", "GetProcessHeap", "FormatMessageW", "InterlockedPushEntrySList", "CloseHandle", "LoadLibraryW", "FreeLibrary", "GetProcAddress", "SetErrorInfo", "GetErrorInfo", "CoInitializeEx", "CoCreateFreeThreadedMarshaler", "CoTaskMemAlloc", "SysAllocString", "SysFreeString", "SysStringLen", "MultiByteToWideChar", "WideCharToMultiByte", "HeapAlloc", "HeapFree", "GetProcessHeap", "FormatMessageW", "InterlockedPushEntrySList", "CloseHandle"
    ]
  {.passL: fmt"/link {linkLibs.join("" "")} {alternates.getAlternateNames}" .}
  # {.passL:   linkLibs.join(" ").}
  # {.passL: "/link /LIBPATH:" & currentSourcePath.parentDir/../"webview"/"dll"/"x64".}
  # cIncludeDir("""C:\Program Files (x86)\Windows Kits\10\Include\10.0.19041.0""")
  cIncludeDir(currentSourcePath.parentDir/../"webview"/"script"/"microsoft.web.webview2.1.0.664.37"/"build"/"native"/"include")
  when false: #msvc
    cPassC("-std=gnu++17 -fcoroutines")
    cIncludeDir(currentSourcePath.parentDir)
    cIncludeDir(currentSourcePath.parentDir/"webview2"/"build"/"native"/"include")
    cDefine("__cpp_lib_coroutine")
    cDefine("__clang__")
    cDefine("__linux__")
  # {.fatal: "Not implemented".}
elif defined(macosx):
  {.fatal: "Not implemented".}

when not defined(cpp):
  {.fatal: "Webview requires cpp backend! Compile with: \"nim cpp filename.nim\"".}

static:
  when defined(printWrapper):
    cDebug()                                                # Print wrapper to stdout

const
  baseDir = currentSourcePath/../""/../"webview"

# getHeader(
#   "webview.h",                                             # The header file to wrap, full path is returned in `headerPath`
#   giturl = "https://github.com/webview/webview.git",            # Git repo URL
#   outdir = baseDir,                                       # Where to download/build/search
#   # conFlags = "--disable-comp --enable-feature",           # Flags to pass configure script
#   # cmakeFlags = "-DENABLE_STATIC_LIB=ON"                   # Flags to pass to Cmake
#   # altNames = "hdr"                                        # Alterate names of the library binary, full path returned in `headerLPath`
# )

# Wrap headerPath as returned from getHeader() and link statically
# or dynamically depending on user input
# when not isDefined(headerStatic):
#   cImport(headerPath, recurse = true, dynlib = "headerLPath")       # Pass dynlib if not static link
# else:
# cPassC("-xc++")
# cPassL("-xc++")

# when false:
#   static:
#   #   cAddStdDir(mode = "cpp")
#   #   echo baseDir/"webview.h"
#     for f in [baseDir/"webview.h"]:
#       for i in [
#         ("\n#define WEBVIEW_API extern\n", "\n#define WEBVIEW_API extern inline\n"),
#   #       ("sync_binding_t", "string")
#       ]:
#         f.writeFile f.readFile.replace(i[0], i[1])

# cPassC(pkgconfigFlags)
# static:
#   echo pkgconfigFlags.getPkgconfigDirs()
  # Remove C++ methods

cPlugin:
  import strutils
  # import nimterop/globals

  const skipSymbols =
      @[
        # Linux
        "window", "run", "terminate", "dispatch", "set_size", "set_title",
        "navigate", "init", "eval", "bind", "on_message", "resolve",
        "hex2nibble", "hex2char", "json_parse_c", "json_unescape",
        # Windows
        "embed", "resize", "to_lpwstr", "AddRef", "Release",
        "QueryInterface", "Invoke",
        # Override on bottom
        "webview_bind"
      ]

  proc onSymbol*(sym: var Symbol) {.exportc, dynlib.} =
    case sym.kind
      of nskProc:
        if sym.name in skipSymbols:
          sym.name = ""
        else:
          sym.name = sym.name.replace("webview_", "")
      of nskType:
        if sym.name == "webview_t":
          sym.name = "Webview"
      else: discard
  # proc onSymbolOverride*(sym: var Symbol) {.exportc, dynlib.} =
  #   case sym.kind
  #     of nskProc:
  #       # if sym.name == "webview_bind":
  #         sym.override = "proc webview_bind*()"
  #         sym.name = "`bind`"
  #     else: sym.override = "asdasdasd"
    # sym.name = ""
    # sym.name = sym.name.strip(chars={'_'}).replace("__", "_")
#     for i in ["G_DATE", "G_HOOK_FLAG", "G_CSET_a", "G_LIST_"]:
#       if sym.name.find(i) != -1:
#         sym.name &= "2"


# cOverride:
#   # proc `bind`*(w: Webview; name: cstring; fn: proc (seq: constCstring; req: constCstring; arg: constCstring) {.cdecl.}; arg: pointer) {.importc: "webview_bind", cdecl, impwebviewHdr.}
#   proc resolve*(seq: string; status: cint; result: string)
#   proc run*(w: string)

cImport(baseDir/"webview.h", recurse = false, mode = "cpp", flags = "")

# proc resolve*(seq: string; status: cint; result: string) {.importc, cdecl, impwebviewHdr.}
# {.passL: "-DWEBVIEW_HEADER".}
# {.passC: "-DWEBVIEW_H".}

type
  cstringConstImpl {.importc:"const char*".} = cstring
  constChar* = distinct cstringConstImpl

converter toConstChar*(s: string): constChar = cast[constChar](s.cstring)
converter `$`*(s: constChar): string  = $cast[cstring](s)


proc `bind`*(w: Webview; name: cstring;
             fn: proc (seq: constChar; req: constChar; arg: pointer) {.cdecl.};
             arg: pointer) {.importcpp: "webview_bind(@)", cdecl, impwebviewHdr.}

# proc wrap(

# proc `bind`*(w: Webview; name: cstring;
#              fn: proc (seq: cstring; req: cstring; arg: pointer) {.cdecl.};
#              arg: pointer) =
#              `bind`(w, name, fn, arg)