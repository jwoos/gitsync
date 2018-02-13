# GitSync
This is a program to sync your local repositories with remotes (GitHub, with support for other remotes coming soon).

## Why?
I have multiple devices to use - my desktop, desktop VM, laptop, work laptop, work laptop VM. You can imagine it gets kind of crazy remember what I changed where and whether it's the latest or not. Why not create a program to do that for me? I also prefer to have all copies of my code locally both for my convenience and because I'd rather not lose it because I had my only copy on a server I don't own.

## How?
This will essentially treat your current directory as the local destination to use. It will then get all your remote repositories and check what's available and what's not. If the repository directory doesn't already exist, it will be cloned. Otherwise you will go into the repository and pull in any changes that might have happened. If you're on a branch it will stash those changes and pull the changes on master, switch back to your branch and apply the stash.
