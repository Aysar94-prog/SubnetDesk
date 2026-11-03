#include "../command_line.h"

#include <exception>
#include <iostream>
#include <vector>

struct TrimCase {
  const char* name;
  const char* input;
  const char* expected;
};

int main() {
  const std::vector<TrimCase> cases = {
      {"CM flag", "--cm", "--cm"},
      {"CM with spaces", "--cm   ", "--cm"},
      {"CM with tab", "--cm\t", "--cm"},
      {"CM with newline", "--cm\n", "--cm"},
      {"CM with CRLF", "--cm\r\n", "--cm"},
      {"CM with mixed whitespace", "--cm \n\r\t", "--cm"},
      {"install flag", "--install", "--install"},
      {"connect flag", "--connect", "--connect"},
      {"headless flag", "--cm-no-ui", "--cm-no-ui"},
      {"address", "192.168.1.12:21118", "192.168.1.12:21118"},
      {"single character", "m", "m"},
      {"empty", "", ""},
      {"spaces only", "   ", ""},
      {"whitespace only", " \n\r\t", ""},
      {"interior space", "device name  ", "device name"},
      {"leading whitespace", "  --cm  ", "  --cm"},
      {"UTF-8 value", u8"جهاز", u8"جهاز"},
  };
  int failures = 0;
  for (const auto& test : cases) {
    std::string value(test.input);
    try {
      TrimTrailingArgumentWhitespace(value);
      if (value != test.expected) {
        std::cerr << "FAIL: " << test.name << '\n';
        ++failures;
      }
    } catch (const std::exception& error) {
      std::cerr << "FAIL: " << test.name << ": " << error.what() << '\n';
      ++failures;
    }
  }
  std::cout << cases.size() - failures << '/' << cases.size()
            << " native argument tests passed\n";
  return failures == 0 ? 0 : 1;
}
