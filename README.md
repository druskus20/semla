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

## Development and Running

Configuration is done through environment variables. Check `.env.example`.
There are two modes of operation: local (non persistent) and persistent (using a
database, specifically, supabase).

Building can be done with:

```bash
gleam build --target "javascript"
```

In an effort to avoid having to interact with npm and the javascript ecosystem,
as much as possible, bundling for production is done with the help of a custom
build tool: [bageri](https://github.com/druskus20/bageri). This tool is designed
for personal use.

```bash
bageri -vvv dev
bageri build
```

## On supabase

The frontend connects directly to supabase, supabase handles permissions and
authentication. It is okay to expose `SUPABASE_KEY`, since it is a public anon
key.

[https://supabase.com/docs/guides/api/api-keys](https://supabase.com/docs/guides/api/api-keys)

The database schema includes row level security policies to ensure users can
only access their own data.
