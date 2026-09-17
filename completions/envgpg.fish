complete -c envgpg -f -n '__fish_use_subcommand' -a encrypt -d 'Encrypt .env file'
complete -c envgpg -f -n '__fish_use_subcommand' -a decrypt -d 'Decrypt .env.gpg file'
complete -c envgpg -f -n '__fish_use_subcommand' -a edit -d 'Edit encrypted .env'

complete -c envgpg -f -n '__fish_seen_subcommand_from encrypt' -s n -d 'Dry run expected result'
complete -c envgpg -f -n '__fish_seen_subcommand_from encrypt' -s r -d 'Remove original .env after encryption'
complete -c envgpg -f -n '__fish_seen_subcommand_from encrypt' -s v -d 'Print verbose output'
complete -c envgpg -f -n '__fish_seen_subcommand_from encrypt' -s y -d 'Assume yes for all prompts'

complete -c envgpg -f -n '__fish_seen_subcommand_from decrypt' -s c -d 'Clean by leaving only variables'
complete -c envgpg -f -n '__fish_seen_subcommand_from decrypt' -s e -d "Prepend 'export' before each variable"
complete -c envgpg -f -n '__fish_seen_subcommand_from decrypt' -s m -d 'Mask secrets in the output'

complete -c envgpg -n '__fish_seen_subcommand_from encrypt decrypt edit' -a '(__fish_complete_path)'
