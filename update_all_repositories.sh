find . -maxdepth 1 -type d -exec sh -c 'cd "$0" && [ -d .git ] && git pull origin master' {} \;
