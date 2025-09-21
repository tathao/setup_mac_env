#!/bin/zsh
set -e

echo "🚀 Starting setup for MacBook M1..."

# -------------------------------
# 1. Install Oh My Zsh
# -------------------------------
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "📦 Installing Oh My Zsh..."
  RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  echo "✅ Oh My Zsh already installed, skipping..."
fi

# -------------------------------
# 2. Install Homebrew
# -------------------------------
if ! command -v brew &>/dev/null; then
  echo "📦 Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zshrc"
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  echo "✅ Homebrew already installed, skipping..."
fi

# -------------------------------
# 3. Install packages via Homebrew
# -------------------------------
echo "📦 Installing CLI tools and apps..."
brew install node docker docker-compose colima ollama
brew install --cask miniforge visual-studio-code oracle-jdk zalo messenger omnissa-horizon-client

# -------------------------------
# 4. Setup Conda (Miniforge)
# -------------------------------
echo "🔧 Checking Conda installation..."

# 4. Initialize Conda (from Miniforge) + Create vinagent-env
if [ -d "$HOME/miniforge3" ] || [ -d "$HOME/opt/miniforge3" ] || [ -d "/opt/homebrew/Caskroom/miniforge/base" ]; then
  echo "🔧 Initializing Conda..."

  # Ưu tiên Homebrew Miniforge, fallback sang $HOME
  if [ -x "/opt/homebrew/Caskroom/miniforge/base/bin/conda" ]; then
    CONDA_PATH="/opt/homebrew/Caskroom/miniforge/base/bin/conda"
  elif [ -x "$HOME/miniforge3/bin/conda" ]; then
    CONDA_PATH="$HOME/miniforge3/bin/conda"
  elif [ -x "$HOME/opt/miniforge3/bin/conda" ]; then
    CONDA_PATH="$HOME/opt/miniforge3/bin/conda"
  else
    echo "⚠️ Could not find conda binary, please check Miniforge install."
    exit 1
  fi

  # Run conda init (idempotent)
  $CONDA_PATH init zsh || true

  # Ensure ~/.zshrc contains conda initialize block
  if ! grep -q "conda initialize" "$HOME/.zshrc"; then
    echo "📌 Adding conda initialize block to ~/.zshrc"
    $CONDA_PATH init zsh
  fi

  # Ensure ~/.zprofile sources ~/.zshrc (important for login shells)
  if [ -f "$HOME/.zprofile" ]; then
    if ! grep -q "source ~/.zshrc" "$HOME/.zprofile"; then
      echo '[[ -f ~/.zshrc ]] && source ~/.zshrc' >> "$HOME/.zprofile"
    fi
  else
    echo '[[ -f ~/.zshrc ]] && source ~/.zshrc' >> "$HOME/.zprofile"
  fi

  # Reload conda into current session
  eval "$($CONDA_PATH shell.zsh hook)"

  # Create env from environment.yml if not exists
  if ! conda env list | grep -q "^vinagent-env"; then
    echo "📦 Creating Conda env vinagent-env from environment.yml..."
    conda env create -f environment.yml || {
      echo "⚠️ Failed to create vinagent-env. Try: conda env update -f environment.yml --prune"
    }
  else
    echo "✅ Conda env vinagent-env already exists. Updating..."
    conda env update -f environment.yml --prune
  fi

  # Auto-activate vinagent-env on new shells
  if ! grep -q "conda activate vinagent-env" "$HOME/.zshrc"; then
    echo "conda activate vinagent-env" >> "$HOME/.zshrc"
  fi
else
  echo "⚠️ Miniforge not found! Please check installation."
fi




# -------------------------------
# 5. VSCode Extensions
# -------------------------------
if command -v code &>/dev/null; then
  echo "📦 Installing VSCode extensions..."
  if [ -f "vscode-extensions.txt" ]; then
    while IFS= read -r extension; do
      if [ -n "$extension" ]; then
        code --install-extension "$extension" || true
      fi
    done < vscode-extensions.txt
  else
    echo "⚠️ No vscode-extensions.txt file found, skipping..."
  fi
else
  echo "⚠️ VSCode not installed or 'code' command not available."
fi

# -------------------------------
# 6. Auto-start Colima (Docker backend for M1)
# -------------------------------
echo "🔧 Setting up Colima autostart..."
mkdir -p ~/Library/LaunchAgents
cat > ~/Library/LaunchAgents/com.colima.start.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.colima.start</string>
  <key>ProgramArguments</key>
  <array>
    <string>/opt/homebrew/bin/colima</string>
    <string>start</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <false/>
</dict>
</plist>
EOF
launchctl load ~/Library/LaunchAgents/com.colima.start.plist || true

####################################################
# 7. Setup Continue extension config for VS Code
###################################################

echo "⚙️ Setting up Continue extension config..."

mkdir -p ~/.continue

if [ -f "$HOME/.continue/config.yaml" ]; then
  echo "📂 Backing up existing config.yaml to config.yaml.bak"
  cp "$HOME/.continue/config.yaml" "$HOME/.continue/config.yaml.bak"
fi

cat > "$HOME/.continue/config.yaml" <<'EOF'
name: Local Code Assistant
version: 1.0.0
schema: v1

models:
  - name: deepseek-r1
    provider: ollama
    model: deepseek-r1
    roles:
      - chat

  - name: deepseek-coder
    provider: ollama
    model: deepseek-coder
    roles:
      - autocomplete
      - edit

  - name: qwen2.5-coder
    provider: ollama
    model: qwen2.5-coder
    roles:
      - edit

defaultModel: deepseek-r1

context:
  - provider: code
  - provider: docs
  - provider: diff
  - provider: terminal
  - provider: problems
  - provider: folder
  - provider: codebase

tools:
  terminal: true
  browser: false
  codebase: true

codebase:
  exclude:
    - node_modules
    - .git
    - dist
    - build
    - .next
    - .vscode
    - target
    - __pycache__
    - .mypy_cache
  maxFiles: 1000

customCommands:
  - name: 🐞 Fix Bug (Java / Spring Boot)
    prompt: |
      Fix bugs in this Spring Boot Java code.
      Apply best practices and explain your changes.
    type: edit
    model: qwen2.5-coder

  - name: ⚙️ Generate FastAPI Endpoint
    prompt: |
      Generate a FastAPI endpoint with input validation, response model, and proper docstring.
    type: edit
    model: deepseek-coder

  - name: ♻️ Refactor React Component
    prompt: |
      Refactor this React (TypeScript) component to improve performance, readability, and type safety.
    type: edit
    model: qwen2.5-coder

  - name: 📦 Generate Spring Boot Controller
    prompt: |
      Create a Spring Boot REST controller with request mappings, DTOs, and service injection.
    type: edit
    model: deepseek-coder

  - name: 🧠 Explain Code
    prompt: |
      Explain this code step by step, in plain language, for a junior developer to understand.
    type: edit
    model: deepseek-r1

  - name: 🧪 Generate FastAPI Test
    prompt: |
      Generate a Pytest test case for the FastAPI endpoint.
      Include test client, assertions, and sample inputs.
    type: edit
    model: qwen2.5-coder

  - name: 🧾 Add Docstring (Python)
    prompt: |
      Add detailed docstrings to all functions and classes in this Python code, following Google or NumPy style.
    type: edit
    model: deepseek-r1

  - name: 🧾 Add Javadoc (Java)
    prompt: |
      Add complete Javadoc comments to all methods and classes in this Java code.
      Include description, parameters, return, and exceptions if applicable.
    type: edit
    model: deepseek-r1

  - name: 🧾 Generate OpenAPI from FastAPI
    prompt: |
      Analyze this FastAPI route and generate the corresponding OpenAPI path schema with models and examples.
    type: edit
    model: qwen2.5-coder

  - name: ✅ Generate Unit Test
    prompt: |
      Write a unit test for this function or class in its respective language (Python, Java, or TypeScript).
      Use appropriate testing frameworks (pytest, JUnit, Jest).
    type: edit
    model: qwen2.5-coder

  - name: ✅ Generate Integration Test (API)
    prompt: |
      Generate an integration test that validates full API behavior for this endpoint.
      Include setup, request, response validation, and teardown if necessary.
    type: edit
    model: qwen2.5-coder
EOF

echo "✅ Continue config created at ~/.continue/config.yaml"


# -------------------------------
# 8. Auto-start Ollama serve + pull deepseek
# -------------------------------
echo "🔧 Setting up Ollama autostart..."
mkdir -p ~/Library/LaunchAgents
cat > ~/Library/LaunchAgents/com.ollama.serve.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.ollama.serve</string>
  <key>ProgramArguments</key>
  <array>
    <string>/opt/homebrew/bin/ollama</string>
    <string>serve</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
</dict>
</plist>
EOF
launchctl load ~/Library/LaunchAgents/com.ollama.serve.plist || true

# Wait a few seconds for Ollama server
sleep 5

if [ -f "ollama-models.txt" ]; then
  echo "📦 Pulling Ollama models from ollama-models.txt..."
  while IFS= read -r model || [ -n "$model" ]; do
    if [ -n "$model" ]; then
      echo "   ➡️ Pulling $model"
      ollama pull "$model" || echo "⚠️ Failed to pull model $model"
    fi
  done < ollama-models.txt
else
  echo "⚠️ ollama-models.txt not found, skipping model pulls."
fi

echo "🎉 Setup complete! Please restart your terminal to apply all changes."
