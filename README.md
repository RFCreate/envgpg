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
eval "$(envgpg decrypt -e)"
```

And allow `direnv` to load the environment:

```sh
direnv allow
```

Note: You will be prompted for your GPG passphrase the first time `direnv` loads the environment and whenever the passphrase cache expires.

## Security notes

- Keep the GPG passphrase safe. Losing it means the encrypted file cannot be recovered by this tool.
- Committing the encrypted file is up to the user; this tool neither recommends nor discourages it.
- Treat decrypted output as sensitive, including output redirected to a file or piped into another command.
- `envgpg` does not validate dotenv syntax or manage secrets for you; it passes file content to GPG and applies the requested output transformations.

## Testing

The test suite uses [Bats](https://bats-core.readthedocs.io/):

```sh
bats tests/envgpg.bats
```

## License

See [LICENSE](LICENSE).
