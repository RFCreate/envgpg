# EnvGPG

Protect environment files with GPG.

`envgpg` encrypts `.env` files for storage or sharing, decrypts them to standard output, and lets you edit the encrypted file without leaving a plaintext working copy behind.

## Why envgpg?

- Uses GPG symmetric encryption to protect the file.
- Cleans decrypted data automatically after use.
- Verifies encrypted file against the source.
- Supports masked output, export of variables, and writing to a file.
- Works with `.env` / `.env.gpg` pair as well as custom file names.

## Requirements

- Bash
- GPG (`gpg`)
- Text editor (`vim`/`nano`)

## Installation

Clone or copy this repository, then make the script executable:

```sh
chmod +x envgpg.sh
```

You can run it directly from the repository:

```sh
./envgpg.sh encrypt
```

Or copy the script to a location in your `PATH`:

```sh
cp envgpg.sh /usr/local/bin/envgpg
```

The repository also includes shell [completion files](completions/) for Bash, Fish, and Zsh.

## Quick start

Encrypt the default `.env` file. GPG prompts for the encryption passphrase:

```sh
# Encrypt default
envgpg encrypt

# Encrypt and remove the plaintext source
envgpg encrypt -r

# Change the encryption algorithm
ENVGPG_CIPHER="AES256" envgpg encrypt
```

This creates `.env.gpg`. To inspect the decrypted contents:

```sh
# Print decrypted values
envgpg decrypt

# Print shell-compatible exports
envgpg decrypt -e

# Review the file without exposing secret values in the terminal
envgpg decrypt -m

# Save decrypted content to a file
envgpg decrypt > .env
```

Edit the encrypted file in your configured editor:

```sh
# Use the configured editor to edit the encrypted file
EDITOR="vim" envgpg edit
```

After the editor closes, the file is re-encrypted, no plaintext copy remains.

## Integration with direnv

To automatically load environment variables from an encrypted `.env.gpg` file using `direnv`, add the following to your `.envrc`:

```sh
eval "$(envgpg decrypt -ce)"
```

And allow `direnv` to load the environment:

```sh
direnv allow
```

Note: You will be prompted for your GPG passphrase the first time `direnv` loads the environment and whenever the passphrase cache expires.

## Use it in CI pipelines

You can use `envgpg` in your CI pipelines to decrypt environment variables securely. For example:

```sh
eval "$(ENVGPG_PASSPHRASE="$SECRET_PASSPHRASE" envgpg decrypt -ce)"
```

## Security notes

- Keep the GPG passphrase safe. Losing it means the encrypted file cannot be recovered by this tool.
- Committing the encrypted file is up to the user; this tool neither recommends nor discourages it.
- Treat decrypted output as sensitive, including output redirected to a file or piped into another command.
- `envgpg` does not validate dotenv syntax or manage secrets for you; it passes file content to GPG and applies the requested output transformations.

## Testing

This project includes a Bats test suite covering the command-line behavior, encryption/decryption flows, and editor integration.

```sh
# Run the automated checks
bats tests/envgpg.bats
```

## Contributing

Contributions are welcome. Please review [CONTRIBUTING.md](CONTRIBUTING.md) before submitting changes. The guide covers the project conventions for new flags, required test coverage, and syncing shell completions with the CLI.

## License

This project is licensed under the [MIT License](LICENSE).
