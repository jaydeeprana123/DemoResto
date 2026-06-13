#include "reveal_pdf_helper.h"

#include "utils.h"

#include <shlobj.h>
#include <shellapi.h>
#include <windows.h>

#include <algorithm>
#include <cctype>
#include <string>

namespace {

std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) {
    return std::wstring();
  }
  const int length = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
  if (length <= 0) {
    return std::wstring();
  }
  std::wstring wide(static_cast<size_t>(length - 1), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, wide.data(), length);
  return wide;
}

std::string ToLowerAscii(std::string value) {
  std::transform(value.begin(), value.end(), value.begin(),
                 [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
  return value;
}

std::string UrlDecode(const std::string& value) {
  std::string decoded;
  decoded.reserve(value.size());
  for (size_t i = 0; i < value.size(); ++i) {
    if (value[i] == '+') {
      decoded.push_back(' ');
      continue;
    }
    if (value[i] == '%' && i + 2 < value.size()) {
      const auto hex = value.substr(i + 1, 2);
      char* end = nullptr;
      const long code = strtol(hex.c_str(), &end, 16);
      if (end == hex.c_str() + 2) {
        decoded.push_back(static_cast<char>(code));
        i += 2;
        continue;
      }
    }
    decoded.push_back(value[i]);
  }
  return decoded;
}

std::string ExtractQueryParam(const std::string& url, const std::string& key) {
  const auto query_start = url.find('?');
  if (query_start == std::string::npos) {
    return std::string();
  }
  const std::string query = url.substr(query_start + 1);
  const std::string key_prefix = key + "=";
  size_t pos = 0;
  while (pos < query.size()) {
    const auto amp = query.find('&', pos);
    const auto part = query.substr(pos, amp == std::string::npos ? std::string::npos : amp - pos);
    if (part.rfind(key_prefix, 0) == 0) {
      return part.substr(key_prefix.size());
    }
    if (amp == std::string::npos) {
      break;
    }
    pos = amp + 1;
  }
  return std::string();
}

std::wstring GetKnownFolderPath(REFKNOWNFOLDERID folder_id) {
  PWSTR path = nullptr;
  if (FAILED(SHGetKnownFolderPath(folder_id, 0, nullptr, &path)) || path == nullptr) {
    return std::wstring();
  }
  std::wstring result(path);
  CoTaskMemFree(path);
  return result;
}

std::wstring CombinePath(const std::wstring& directory, const std::wstring& file_name) {
  if (directory.empty()) {
    return file_name;
  }
  if (directory.back() == L'\\' || directory.back() == L'/') {
    return directory + file_name;
  }
  return directory + L"\\" + file_name;
}

bool FileExists(const std::wstring& path) {
  const DWORD attributes = GetFileAttributesW(path.c_str());
  return attributes != INVALID_FILE_ATTRIBUTES &&
         (attributes & FILE_ATTRIBUTE_DIRECTORY) == 0;
}

std::wstring SanitizeFileName(const std::wstring& file_name) {
  std::wstring safe = file_name;
  const wchar_t invalid[] = {L'<', L'>', L':', L'"', L'|', L'?', L'*', L'\0'};
  for (wchar_t& ch : safe) {
    if (wcschr(invalid, ch) != nullptr) {
      ch = L'_';
    }
  }
  return safe;
}

std::wstring FindReceiptPdfPath(const std::wstring& file_name) {
  const std::wstring safe_name = SanitizeFileName(file_name);
  const std::wstring downloads = GetKnownFolderPath(FOLDERID_Downloads);
  const std::wstring documents = GetKnownFolderPath(FOLDERID_Documents);
  const std::wstring receipts_dir = CombinePath(documents, L"Flavor Flow Receipts");

  const std::wstring candidates[] = {
      CombinePath(downloads, safe_name),
      CombinePath(receipts_dir, safe_name),
  };

  for (const auto& candidate : candidates) {
    if (FileExists(candidate)) {
      return candidate;
    }
  }
  return std::wstring();
}

bool RevealInExplorer(const std::wstring& path) {
  if (path.empty()) {
    return false;
  }
  const std::wstring params = L"/select,\"" + path + L"\"";
  const HINSTANCE result =
      ShellExecuteW(nullptr, L"open", L"explorer.exe", params.c_str(), nullptr, SW_SHOWNORMAL);
  return reinterpret_cast<intptr_t>(result) > 32;
}

std::wstring GetExePath() {
  wchar_t path[MAX_PATH];
  const DWORD length = GetModuleFileNameW(nullptr, path, MAX_PATH);
  if (length == 0 || length >= MAX_PATH) {
    return std::wstring();
  }
  return std::wstring(path);
}

void WriteRegString(HKEY root, const std::wstring& sub_key, const std::wstring& value_name,
                    const std::wstring& data) {
  HKEY key = nullptr;
  if (RegCreateKeyExW(root, sub_key.c_str(), 0, nullptr, 0, KEY_SET_VALUE, nullptr, &key,
                      nullptr) != ERROR_SUCCESS) {
    return;
  }
  RegSetValueExW(key, value_name.empty() ? nullptr : value_name.c_str(), 0, REG_SZ,
                 reinterpret_cast<const BYTE*>(data.c_str()),
                 static_cast<DWORD>((data.size() + 1) * sizeof(wchar_t)));
  RegCloseKey(key);
}

}  // namespace

bool IsFlavorFlowDeepLink(const std::vector<std::string>& args) {
  for (const auto& arg : args) {
    const auto lower = ToLowerAscii(arg);
    if (lower.rfind("flavorflow://", 0) == 0) {
      return true;
    }
  }
  return false;
}

bool TryHandleRevealPdfDeepLink(const std::vector<std::string>& args) {
  for (const auto& arg : args) {
    const auto lower = ToLowerAscii(arg);
    if (lower.rfind("flavorflow://", 0) != 0) {
      continue;
    }
    if (lower.find("reveal-pdf") == std::string::npos) {
      continue;
    }

    const auto encoded_name = ExtractQueryParam(arg, "name");
    if (encoded_name.empty()) {
      return false;
    }

    const auto decoded_name = UrlDecode(encoded_name);
    const auto wide_name = Utf8ToWide(decoded_name);
    if (wide_name.empty()) {
      return false;
    }

    const auto path = FindReceiptPdfPath(wide_name);
    if (path.empty()) {
      return false;
    }

    return RevealInExplorer(path);
  }
  return false;
}

void EnsureFlavorFlowProtocolRegistered() {
  HKEY existing = nullptr;
  if (RegOpenKeyExW(HKEY_CURRENT_USER, L"Software\\Classes\\flavorflow", 0, KEY_READ,
                    &existing) == ERROR_SUCCESS) {
    RegCloseKey(existing);
    return;
  }

  const std::wstring exe_path = GetExePath();
  if (exe_path.empty()) {
    return;
  }

  const std::wstring command = L"\"" + exe_path + L"\" \"%1\"";
  WriteRegString(HKEY_CURRENT_USER, L"Software\\Classes\\flavorflow", L"", L"URL:Flavor Flow Protocol");
  WriteRegString(HKEY_CURRENT_USER, L"Software\\Classes\\flavorflow", L"URL Protocol", L"");
  WriteRegString(HKEY_CURRENT_USER, L"Software\\Classes\\flavorflow\\shell\\open\\command", L"",
                 command);
}
