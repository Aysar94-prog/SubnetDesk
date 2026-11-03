#ifndef RUNNER_COMMAND_LINE_H_
#define RUNNER_COMMAND_LINE_H_

#include <string>

// Remove only trailing whitespace; launch flags must remain intact.
inline void TrimTrailingArgumentWhitespace(std::string& argument) {
  const auto last = argument.find_last_not_of(" \n\r\t");
  if (last == std::string::npos) {
    argument.clear();
  } else {
    argument.erase(last + 1);
  }
}

#endif  // RUNNER_COMMAND_LINE_H_
