# Color output (auto set to 'no' on dumb terminals).
zstyle ':prezto:*:*' color 'yes'

# Set the Prezto modules to load (browse modules).
# The order matters.
zstyle ':prezto:load' pmodule \
  'environment' \
  'terminal' \
  'editor' \
  'history' \
  'utility' \
  'completion' \
  'autosuggestions' \
  'syntax-highlighting'
  
# Set the key mapping style to 'emacs' or 'vi'.
zstyle ':prezto:module:editor' key-bindings 'emacs'

# Set syntax highlighters.
# By default, only the main highlighter is enabled.
zstyle ':prezto:module:syntax-highlighting' highlighters \
  'main' \
  'brackets' \
  'pattern' \
  'line'

# Enabled safe options. This aliases cp, ln, mv and rm so that they prompt
# before deleting or overwriting files. Set to 'no' to disable this safer
# behavior.
zstyle ':prezto:module:utility' safe-ops 'no'