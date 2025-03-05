#!/bin/bash

# 1. Git 커밋 템플릿 설정
echo "📌 Setting up Git commit template..."
git config --local commit.template .git-commit-template

# 2. Husky 설치 (이미 설정되어 있으면 생략)
if [ ! -d ".husky" ]; then
  echo "📌 Installing Husky..."
  npx husky install
fi

# 3. Husky 커밋 메시지 검증 Hook 추가 (이미 존재하는지 확인 후 생성)
if [ ! -f ".husky/commit-msg" ]; then
  echo "📌 Adding commit-msg hook for commitlint..."
  npx husky add .husky/commit-msg "npx --no-install commitlint --edit \$1"
fi

# 4. 실행 권한 부여 (혹시 모를 권한 문제 방지)
chmod -R +x .husky

# 5. 완료 메시지
echo "✅ Setup complete! You're ready to start coding. 🚀"
``
