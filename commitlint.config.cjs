module.exports = {
  extends: ['@commitlint/config-conventional'], // Conventional Commits 확장
  rules: {
    'type-enum': [2, 'always', ['dhyun2', 'HyeonjiKwon', 'Joie-Kim']], // GitHub ID 강제
    'type-empty': [2, 'never'], // type은 비워둘 수 없음
    'scope-empty': [2, 'never'], // scope(설명 부분)도 반드시 입력해야 함
    'subject-empty': [2, 'never'], // 커밋 메시지 내용도 반드시 입력해야 함
    'header-max-length': [2, 'always', 100], // 커밋 메시지 길이 제한 (100자 이하)
  },
};
