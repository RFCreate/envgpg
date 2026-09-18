# Contributing to EnvGPG

Thank you for contributing to EnvGPG! Changes should preserve the command-line interface and keep its documentation, tests, and shell completions in sync.

## Choosing Between Environment Variables and Flags

Before adding a command-line flag, determine whether the option only changes GPG behavior.

- If the option only changes GPG behavior, add it as an environment variable using the project-specific `ENVGPG_` prefix. For example, `ENVGPG_CIPHER` controls the GPG cipher algorithm.
- Environment variables that meet this GPG-only criterion do not require test cases.
- If the option does more than change GPG behavior, add it as a command-line flag and complete all requirements below.

Keep environment variables documented in the relevant usage message and README examples if relevant. Do not introduce a command-line flag when an `ENVGPG_*` variable is the appropriate interface.

## Keeping the Edit Command Simple

Keep the `edit` command free of flags whenever possible. If a new edit option requires a flag, explain why the behavior cannot be handled by the existing command or an environment variable.

## Adding a Command-Line Flag

When adding a new flag:

1. Update the command's usage message in `envgpg.sh` with the flag and a concise description.
2. Add appropriate test cases in `tests/envgpg.bats`, covering the flag's observable behavior and important edge cases.
3. Update every completion script in `completions/`.

A flag is not complete until all three surfaces are updated: usage documentation, automated tests, and shell completions.

## Contributor Checklist

Before submitting a change, verify that:

- GPG-only behavior uses an `ENVGPG_*` environment variable instead of a flag.
- The `edit` command remains flag-free unless a new flag is properly justified.
- New command-line flags appear in the appropriate usage message.
- New command-line flags have appropriate Bats test cases.
- New command-line flags are available in Bash, Fish, and Zsh completions.
- Existing behavior and interfaces remain unchanged unless the change explicitly requires otherwise.
