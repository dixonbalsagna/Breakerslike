# Git and GitHub setup (Windows, Git Bash)

Kept here because it is easy to forget. Every command also works in PowerShell.

## Link this folder to GitHub (first time)

1. Open Git Bash in the project folder: right-click the folder in File Explorer, then *Show more options*, then *Open Git Bash here*. Or `cd` into your project folder (put the path in quotes if it contains a space).
2. Sign in to GitHub once per computer:
   `gh auth login --hostname github.com --git-protocol https --web`
   Answer **Y** if asked to authenticate Git with your GitHub credentials. Copy the one-time code, press Enter, paste the code in the browser page that opens, and click Authorize. Check it worked with `gh auth status`.
3. See whether the repo already exists: `gh repo view dixonbalsagna/Breakerslike`
4. If it does **not** exist, create it and push in one go:
   `gh repo create dixonbalsagna/Breakerslike --private --source=. --remote=origin --push`
5. If it **does** exist:
   `git remote add origin https://github.com/dixonbalsagna/Breakerslike.git`
   `git push -u origin main`
   If the push is rejected because GitHub already has files (for example a README made on the website), run `git pull origin main --allow-unrelated-histories` and push again.
6. Check: `git status` should say *up to date with 'origin/main'*.

Why HTTPS rather than the `git@github.com:` SSH address: HTTPS through `gh` needs no SSH keys, and every Claude session on the machine can then push without prompts.

## On a new computer

1. Install Git for Windows and GitHub CLI (`winget install Git.Git GitHub.cli`).
2. `git config --global user.name "dixonbalsagna"`
3. `git config --global user.email "<your GitHub noreply address>"`
4. `gh auth login --hostname github.com --git-protocol https --web`
5. `gh repo clone dixonbalsagna/Breakerslike`

## Renaming the repo later

GitHub repo Settings, then Repository name. GitHub redirects the old address, and `git remote set-url origin <new https url>` updates this folder.
