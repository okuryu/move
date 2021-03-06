#!/bin/bash
SRC_DIR="$(perl -e "use Cwd; use Cwd 'realpath'; print realpath('${0}');" | xargs dirname)"
DST_DIR="$(perl -e "use Cwd; use Cwd 'realpath'; print realpath('${SRC_DIR}');" | xargs dirname)"
BUILD_DST_DIR="${SRC_DIR}/.build"
DST_DIR="${DST_DIR}/web_generated"
GIT_SRC_DIR="$(dirname "$SRC_DIR")"

echo "Building from ${SRC_DIR} -> ${DST_DIR}"

MOVE_BIN="${SRC_DIR}/../bin/move"

cd "$SRC_DIR" || exit $?

# Check if DST_DIR is ok
if [ ! -d "$DST_DIR" ] || [ "$(git --git-dir="${DST_DIR}/.git" branch --no-color | sed -e '/^[^*]/d' -e "s/* \(.*\)/\1/")" != "gh-pages" ]; then
  # Backup if modified
  if [ -d "$DST_DIR" ]; then
    BACKUP_DIR="${DST_DIR}_backup_"$(date +%s)
    echo "WARNING: ${DST_DIR} has been modified. Moving to ${BACKUP_DIR}"
    rm -rf "$BACKUP_DIR" || exit $?
    mv "$DST_DIR" "$BACKUP_DIR" || exit $?
  fi

  # Clone
  git clone --local --shared --no-checkout -- \
    "$GIT_SRC_DIR" "$DST_DIR" || exit $?

  cd "$DST_DIR" || exit $?

  # Create or checkout gh-pages branch
  if (git show-ref --heads --quiet gh-pages); then
    git checkout gh-pages || exit $?
  else
    git symbolic-ref HEAD refs/heads/gh-pages || exit $?
    rm -f .git/index
  fi
  echo git clean -fdx || exit $?

  # Back home
  cd "$SRC_DIR" || exit $?
fi

# Build move
"$MOVE_BIN" build-weblib || exit $?

# Build website
rm -rf "$BUILD_DST_DIR"
jekyll --no-server --no-auto "$BUILD_DST_DIR" || exit $?
mv "$DST_DIR/.git" "$BUILD_DST_DIR/.git" || exit $?
rm -rf "$DST_DIR"
mv -f "$BUILD_DST_DIR" "$DST_DIR" || exit $?

# Create .nojekyll
touch "$DST_DIR/.nojekyll"

# Commit
cd "$DST_DIR" || exit $?
git add . || exit $?
if (git commit --no-status -a -m 'Generated website'); then
  git remote set-url origin "$GIT_SRC_DIR" || exit $?
  if ! (git push origin gh-pages 2>/dev/null); then
    git pull origin gh-pages || exit $?
    git push origin gh-pages || exit $?
  fi
fi

# Back home
#cd "$SRC_DIR" || exit $?

echo "---- Done ---- Deploy with:"
echo "  git push origin gh-pages"
