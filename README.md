# Semla

## Setup 

### Prequisites

#### Install asdf

Install [asdf](https://github.com/asdf-vm/asdf/releases/tag/v0.18.0) in `$PATH` 

```bash
export PATH="$XDG_DATA_HOME/asdf/shims:$PATH"
```

Add to `.zprofile` and also run in current shell

#### Use asdf to install dependencies

Install gleam and erlang plugins

```bash
asdf plugin add gleam
asdf plugin add erlang
asdf plugin add rebar
```

```bash
asdf install gleam 1.13.0 
asdf install erlang 28.1.1
assdf install rebar 3.25.1


# Set as global versions
asdf set --home gleam 1.13.0
asdf set --home erlang 28.1.1
asdf set --home rebar 3.25.1
```

