# 📌 빌드 시스템 스터디 (1주차)

## 🎯 스터디 목표

빌드 시스템은 프런트엔드 개발에서 필수적인 요소이며, 프로젝트의 규모가 커질수록 더욱 중요해집니다. 이번 스터디에서는 **빌드 시스템이란 무엇이며, 어떤 역할을 하는지**에 대해 학습하고, 빌드 시스템 없이 자바스크립트 라이브러리를 로드하는 방법을 실험해 봅니다.

## 📝 1주차 목표

이번 주차에서는 아래의 두 글을 읽고 **빌드 시스템의 필요성과 대안**을 탐색합니다.

🔗 **원문**: [빌드 시스템 없이 프런트엔드 자바스크립트 라이브러리 가져오기](https://jvns.ca/blog/2024/11/18/how-to-import-a-javascript-library/)
🔗 **번역문**: [번역된 글](https://junghan92.medium.com/%EB%B2%88-%EB%B9%8C%EB%93%9C-%EC%8B%9C%EC%8A%A4%ED%85%9C-%EC%97%86%EC%9D%B4-%ED%94%84%EB%9F%B0%ED%8A%B8%EC%97%94%EB%93%9C-%EC%9E%90%EB%B0%94%EC%8A%A4%ED%81%AC%EB%A6%BD%ED%8A%B8-%EB%9D%BC%EC%9D%B4%EB%B8%8C%EB%9F%AC%EB%A6%AC-%EB%B6%88%EB%9F%AC%EC%98%A4%EA%B8%B0-744dc965ece0)

## 🔍 빌드 시스템이란?

빌드 시스템은 프런트엔드 개발에서 다음과 같은 역할을 합니다.

- 📦 **번들링(Bundling)**: 여러 개의 JS 파일을 하나의 파일로 합쳐 네트워크 요청을 줄임
- ✂️ **트리 쉐이킹(Tree Shaking)**: 사용되지 않는 코드를 제거하여 번들 크기를 줄임
- 🎭 **코드 변환(Transpiling)**: 최신 JS 코드를 오래된 브라우저에서도 실행 가능하도록 변환
- 📌 **최적화(Minification, Compression)**: 코드 크기를 최소화하여 로딩 속도 향상
- 🔄 **핫 모듈 리플레이스먼트(HMR)**: 코드 변경 시 브라우저 새로고침 없이 즉시 반영

### ✅ 대표적인 빌드 시스템 & 도구들

| 🚀 빌드 도구 | 💡 주요 특징                                    |
| ------------ | ----------------------------------------------- |
| **Webpack**  | 가장 널리 사용되는 번들러, 다양한 플러그인 지원 |
| **Vite**     | 빠른 개발 서버 제공, ES 모듈 기반 빌드          |
| **Rollup**   | 라이브러리 번들링 최적화, 트리 쉐이킹 강력함    |
| **Parcel**   | 설정 없이 사용 가능, 자동 코드 스플리팅         |
| **esbuild**  | 초고속 빌드 성능, JS/TS 지원                    |

## 🏆 1주차 학습 목표

1️⃣ **빌드 시스템 없이 자바스크립트 라이브러리를 불러오는 방법** 이해하기  
2️⃣ **ESM, CommonJS, 글로벌 스크립트 방식의 차이** 학습하기  
3️⃣ **기존 빌드 시스템(Webpack, Vite 등)과 비교하여 장단점 분석**하기

## ❓ 고민할 질문

- 빌드 시스템이 없으면 어떤 문제가 발생할까? 🤔
- 브라우저 네이티브 모듈 로딩(ESM)과 번들링의 차이는? ⚡
- CommonJS 모듈을 브라우저에서 직접 실행할 수 없는 이유는? 🧐
- `importmap`을 사용하면 빌드 시스템 없이도 가능할까? 🏗️

## 📌 마무리

이번 주차에서는 빌드 시스템 없이 자바스크립트 라이브러리를 로드하는 방법을 배우면서 **빌드 시스템이 왜 필요한지, 어떤 대안이 존재하는지** 고민해 봅시다!
