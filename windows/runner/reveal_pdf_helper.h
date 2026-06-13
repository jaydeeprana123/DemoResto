#ifndef RUNNER_REVEAL_PDF_HELPER_H_
#define RUNNER_REVEAL_PDF_HELPER_H_

#include <string>
#include <vector>

// Returns true when [args] contain a flavorflow:// deep link.
bool IsFlavorFlowDeepLink(const std::vector<std::string>& args);

// Handles flavorflow://reveal-pdf?name=<file.pdf> by selecting the file in Explorer.
// Returns true when the file was found and Explorer opened.
bool TryHandleRevealPdfDeepLink(const std::vector<std::string>& args);

// Registers flavorflow:// in HKCU so the web app can reveal downloaded PDFs.
void EnsureFlavorFlowProtocolRegistered();

#endif  // RUNNER_REVEAL_PDF_HELPER_H_
