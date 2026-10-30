# installcanary.sh

Would your npm run a package's install script? Would it install a release that was published ten minutes ago?

Those were the two steps that reached developers' machines in the Cline CLI incident (Feb 2026): `cline@2.3.0` was a
normal release plus one `postinstall` line, `npm install -g openclaw@latest`, and it was live for about eight hours.

```
./installcanary.sh                      # check `npm` with your own config
./installcanary.sh -- npx -y npm@12     # check another npm
```

```
installcanary: npm 10.9.9
  install scripts    RAN       a package's postinstall ran during install
  min-release-age    ignored   npm 10.9.9 doesn't support it (needs 11.10.0+), whatever it's set to
installcanary: EXPOSED: see README for the two settings
```

It installs a harmless local package (its `postinstall` writes one file inside a temp project) with your npm and your
config, then reads your release-age setting. No network. Exit code 0 means both are covered (HELD), 1 means at least one
isn't (EXPOSED), 2 means usage, 3 means npm itself failed, so nothing was measured.

## The two settings

In `~/.npmrc`:

```
ignore-scripts=true
min-release-age=1
```

- **`ignore-scripts=true`** stops install scripts. npm 12 blocks dependency install scripts by default unless you approve
  a package by name (`npm install-scripts approve`), so on npm 12 you can use that instead.
- **`min-release-age=1`** refuses any version published in the last day. A one-day delay would have skipped the eight-hour
  window. **npm only honours it from 11.10.0.** With `min-release-age=1` in `.npmrc`, npm 10.9.9 installed a version
  published minutes earlier without a warning; 11.9.0 printed `Unknown project config "min-release-age"` and installed it
  anyway; 11.10.0 refused it.
  pnpm has the same idea as `minimumReleaseAge`.

The cost: some packages need their install scripts (you'll approve those by name), and a delay also delays security
fixes by a day.

## If you run an AI bot on GitHub issues

- An issue title is untrusted input written by a stranger. Don't use `allowed_non_write_users: "*"` with Bash; Anthropic's
  claude-code-action docs call it "a significant security risk" and suggest e.g. `--allowedTools "Bash(gh issue view:*)"`.
- Keep caches away from jobs that can publish (`cache-mode: none`, or `package-manager-cache: false` in setup-node).
  Since 26 June 2026 GitHub gives runs from untrusted triggers read-only access to the default branch's cache, which
  closes the step Cline lost its token through, unless a workflow opts back in with a write `cache-mode`.
- Publish with npm trusted publishing, then set "Require two-factor authentication and disallow tokens".

Checked 29 Oct 2026. Tests: `sh test/test.sh` (no network).

Sources: https://adnanthekhan.com/posts/clinejection/ · https://cline.bot/blog/post-mortem-unauthorized-cline-cli-npm ·
https://github.blog/changelog/2026-06-26-read-only-actions-cache-for-untrusted-triggers/ ·
https://docs.npmjs.com/cli/v12/using-npm/config · https://docs.npmjs.com/trusted-publishers
