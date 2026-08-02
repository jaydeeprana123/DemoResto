#ifndef RUNNER_REVEAL_PDF_HELPER_H_
#define RUNNER_REVEAL_PDF_HELPER_H_

#include <string>
#include <vector>

// Returns true when [args] contain a smartkitchen:// deep link.
bool IsSmartKitchenDeepLink(const std::vector<std::string>& args);

// Handles smartkitchen://reveal-pdf?name=<file.pdf> by selecting the file in Explorer.
// Returns true when the file was found and Explorer opened.
bool TryHandleRevealPdfDeepLink(const std::vector<std::string>& args);

// Registers smartkitchen:// in HKCU so the web app can reveal downloaded PDFs.
void EnsureSmartKitchenProtocolRegistered();

#endif  // RUNNER_REVEAL_PDF_HELPER_H_
