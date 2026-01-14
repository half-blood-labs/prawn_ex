# Contributing to PrawnEx

Thanks for your interest in contributing.

## Setup

```bash
git clone https://github.com/prawn-ex/prawn_ex.git
cd prawn_ex
mix deps.get
```

## Running tests

```bash
mix test
```

## Code style

Format code before submitting:

```bash
mix format
```

## Submitting changes

1. Open an issue or comment on an existing one to discuss the change.
2. Fork the repo, create a branch, and make your changes.
3. Run `mix format` and `mix test`.
4. Open a pull request with a short description of the change.

## Demo

Generate the demo PDF to verify the library works end-to-end:

```bash
mix run scripts/gen_demo.exs
```

Output is written to `output/prawn_ex_demo.pdf`.
