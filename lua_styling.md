# Lua Quality & Styling Guide for APISIX & Kong

This guide covers the setup, configuration, and comparison of linters and formatters optimized for OpenResty-based API gateways like Apache APISIX and Kong.

---

## 1. Linting with Selene

[Selene](https://github.com/Kampfkarren/selene) is an incredibly fast, AST-based Lua linter written in Rust. It is highly recommended for OpenResty development because it allows you to define custom global variables (like `ngx`, `kong`, or `ndk`) to prevent false-positive "undefined variable" errors.

### 📊 Linter Comparison

| Feature | 🚀 Selene | 🛠️ Luacheck | 💎 Luau Linter |
| :--- | :--- | :--- | :--- |
| **Written In** | Rust | Lua | C++ |
| **Performance** | Extremely fast (multithreaded) | Slower (single-threaded) | Extremely fast |
| **Configuration** | `selene.toml` (TOML) | `.luacheckrc` (Lua) | `.luaurc` (JSON) |
| **Maintenance** | Actively maintained | Mostly inactive | Actively maintained |
| **Best Used For** | OpenResty, Kong, Neovim, standard Lua | Legacy codebases | Roblox / Luau engines |

### ⚙️ Selene Configuration (`selene.toml`)

This repository contains a pre-configured [`selene.toml`](file:///Users/smile/workspace/apisix/apisix-custom-plugin/selene.toml) in the root directory. It enforces strict rules to prevent variables from leaking into the global OpenResty worker state.

```toml
# selene.toml
std = "lua51+openresty"

[lints]
# Errors (Deny)
undefined_variable = "deny"
bad_string_escape = "deny"
unscoped_variables = "deny" # Highly recommended to prevent worker memory leaks

# Warnings (Warn)
unused_variable = "warn" # Prefix unused params with `_` to ignore (e.g., `_conf`)
constant_if_condition = "warn"
deprecated = "warn"
divide_by_zero = "warn"
empty_if = "warn"
empty_loop = "warn"
if_same_then_else = "warn"
incorrect_standard_library_use = "warn"
suspicious_reverse_loop = "warn"
unbalanced_assignments = "warn"
unrecognized_opt = "warn"
manual_math_pi = "warn"
manual_math_huge = "warn"

# Allowed (Allow)
multiple_statements = "allow"
shadowing = "warn"
global_usage = "allow"
high_cyclomatic_complexity = "allow"
```

### 🌍 OpenResty Globals (`openresty.yaml`)

Since `+openresty` is appended to the standard library environment inside `selene.toml`, Selene reads [`openresty.yaml`](file:///Users/smile/workspace/apisix/apisix-custom-plugin/openresty.yaml) to whitelist specific global namespaces provided by NGINX / OpenResty.

```yaml
# openresty.yaml
globals:
  # Standard OpenResty / NGINX globals
  ngx:
    any: true
  ndk:
    any: true
  jit:
    any: true

  # ONLY FOR KONG: Uncomment the lines below to whitelist the Kong global
  # kong:
  #   any: true
```

> [!TIP]
> **APISIX Core Best Practice:**
> APISIX generally avoids using global namespaces. Instead, it relies on importing standard modules locally, for example:
> ```lua
> local core = require("apisix.core")
> ```
> This prevents global namespace pollution and improves performance.

---

## 2. Formatting with StyLua

[StyLua](https://github.com/JohnnyMorganz/StyLua) is an opinionated, AST-based formatter written in Rust. It is the de facto standard for code formatting in the modern Lua ecosystem.

### 📊 Formatter Comparison

| Feature | ✨ StyLua | 🛠️ LuaFormatter | 🌐 Prettier (Lua plugin) |
| :--- | :--- | :--- | :--- |
| **Method** | AST parser and reprinter | Modifies whitespace/tokens | Parses to AST via Prettier |
| **Dialects** | Lua 5.1–5.4, LuaJIT, Luau | Standard Lua 5.1–5.4 | Standard Lua 5.1–5.3 |
| **Performance** | Extremely fast | Fast | Slower (Node.js overhead) |
| **Philosophy** | Opinionated (like `gofmt`) | Highly configurable | Highly opinionated |
| **Maintenance** | Actively maintained | Maintenance mode | Third-party plugin |

### 💡 Why StyLua over LuaFormatter for APISIX?

1. **Zero-Breakage Guarantee**: As an AST-based formatter, StyLua builds and prints a syntax tree rather than just performing text search-and-replace on whitespace. This guarantees it will never alter code logic.
2. **Native LuaJIT Support**: OpenResty environments rely on LuaJIT. StyLua natively understands LuaJIT syntax extensions (such as FFI declarations like `ffi.cdef` or the `L` number suffix), whereas generic Lua formatters will trigger syntax parse errors.
3. **Consistency**: Minimal configuration parameters prevent bikeshedding within development teams.
4. **Toolchain Adoption**: It is widely supported by modern editors and systems (Neovim/VS Code extensions, GitHub Actions, etc.).

### ⚙️ Recommended Configuration (`stylua.toml`)

Create a `stylua.toml` file in the root of your project with the following parameters to match the official Apache APISIX codebase style:

```toml
# stylua.toml

# Explicitly set to LuaJIT to support OpenResty syntax and FFI
syntax = "LuaJIT"

# APISIX core standardizes on 4 spaces
indent_type = "Spaces"
indent_width = 4

# Gateway plugins often have long logging statements or nested config tables
column_width = 120

# Standard line endings for Linux/Docker environments
line_endings = "Unix"

# Prefer double quotes, falling back to single if needed
quote_style = "AutoPreferDouble"

# Prefer explicit function calls for clarity (e.g., `require("apisix.core")`)
call_parentheses = "Always"

# Standard Lua formatting conventions
space_after_function_names = "Never"
block_newline_gaps = "Never"
collapse_simple_statement = "Never"
```

### 🛠️ How to Use StyLua

#### **1. Installation**
```bash
# Via Docker
COPY --from=JohnnyMorganz/StyLua:2.5.2 /stylua /usr/bin/stylua
```

```bash
# Via Cargo (Rust package manager)
cargo install stylua

# Via Homebrew (macOS)
brew install stylua

# Via npm (JavaScript toolchain)
npm install -g @stylua/stylua
```

#### **2. Running the Formatter**
```bash
# Check formatting without writing changes
stylua --check apisix/

# Format all Lua files in the project in-place
stylua apisix/
```
