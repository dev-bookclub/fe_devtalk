## Vue에서 SSR과 Hydration 이해하기

> ✍️ 이 글은 Vue에서 SSR을 도입하고자 하는 개발자를 대상으로 SSR의 개념, Hydration의 의미, 그리고 왜 이 둘이 중요한지를 실용적인 관점에서 정리한 글입니다.

---

## 1. SSR(Server-Side Rendering)

**SSR**은 말 그대로 브라우저가 아닌 **서버에서 HTML을 미리 렌더링**하는 기술입니다. Vue 앱을 서버에서 실행하고, 그 결과로 나온 HTML을 클라이언트에 전달합니다.

> ✅ 결과: JS가 실행되기 전에도 완전된 화면을 바로 볼 수 있음

## 동작 호름

1. 사용자가 `/`로 접속
2. 서버가 Vue 컨포\ub10ud를 기본으로 HTML을 만들어서 전송
3. 브라우저는 HTML을 그대로 표시함 (JS 아직 실행 안 된 상황)
4. 이후 JS 번들이 로드

## 언제 사용?

- 검색 엔진 최적화(SEO)가 필요한 페이지
- 초기 렌더링 속도를 빠른것으로 만들고 싶을 경우 (FCP 개정)
- 소설 미디어 공용 시 메타태그 노출 필요 시

---

## 2. Hydration

**Hydration(하이드레이션)**은 SSR으로 만든 정적인 HTML을, **클라이언트 차원에서 Vue 앱으로 활성화하는 과정**입니다.

## 동작 호름

1. 서버가 renderToString으로 HTML 생성
2. 클라이언트는 HTML을 그대로 렌더링
3. JS 번들이 로드되고 Vue 앱이 실행되면
4. 미리 렌더링된 DOM을 분석하고 상태를 동기화함
5. Vue는 이벤트 핸들러 등을 연결

---

## 3. CSR vs SSR + Hydration 비교

| 항목              | CSR                                | SSR + Hydration                       |
| ----------------- | ---------------------------------- | ------------------------------------- |
| 초기 HTML         | 빈 `<div id="app"></div>`          | 완전된 컨테츠 포함                    |
| 첫 화면 표시 속도 | 느릴 수 있음 (JS 실행 이후 렌더링) | 빠름 (즉시 HTML 표시 가능)            |
| SEO               | 불리함 ( 크롤러가 JS 실행 못함)    | 유리함 (HTML에 컨테츠 포함됨)         |
| JS 의집성         | 매우 높음                          | 초기에는 낮고, 이후 Hydration 시 높음 |

---

## 4. Vue에서 SSR과 Hydration 구현 방식

Vue 3에서는 공식적으로 SSR을 지원하고 있으며, 아래처럼 구성됩니다.

### ✅ 서버 사이드 렌더링

```js
import { createSSRApp } from "vue";
import { renderToString } from "@vue/server-renderer";

const app = createSSRApp(App);
const html = await renderToString(app);
```

### ✅ 클라이언트에서 Hydration

```js
import { createSSRApp } from "vue";
import { createApp, createSSRApp, hydrate } from "vue";
import App from "./App.vue";

const app = createSSRApp(App);
app.mount("#app"); // SSR일 경우 자동으로 Hydration 진행
```

> Vue는 SSR 환경에서 mount할 때 자동으로 hydration을 시도

---

## 5. 주의할 점

- 서버에서 상태가 공유되면 안 됩니다.

  > store = globalStore처럼 하면 여러 사용자의 요청이 꼬일 수 있음

- Hydration 오류는 눈에 잘 안 띄지만, 버그의 원인이 됩니다.

  > HTML 구조가 클라이언트와 다르면 “hydration mismatch” 경고 발생

- 초기 데이터를 클라이언트에 함께 내려줘야 합니다.
  > 서버에서 fetch한 데이터를 window.**INITIAL_STATE** 같은 변수로 내려주고, 클라이언트에서 이를 pinia나 vuex에 주입해야 함

---

## 6. 실전에서 느기는 차이점

| 항목         | CSR                        | SSR + Hydration                   |
| ------------ | -------------------------- | --------------------------------- |
| ⏱️ 초기 속도 | JS 로드후 렌더링됨         | HTML 먼저, JS는 나중에 실행       |
| 🔍 SEO       | 메타태그, 본문 노출 안 됨  | 완전 노출됨 (SNS 썸네일 포함)     |
| 🧠 초기 UX   | 로딩 스피너만 보일 수 있음 | 바로 컨텐츠 확인 가능             |
| ⚙️ 서버 부회 | 적음                       | 많음 (매 요청마다 HTML 생성 필요) |

---

## ✅ 결론

- SSR은 사용자 경험과 SEO를 개선하는 강력한 도구지만, 복잡성과 서버 부하를 동반합니다.

- Hydration은 SSR의 필수 동반자이며, 이를 제대로 이해해야 상태 동기화 및 에러를 방지할 수 있어요.

- Vue에서는 공식적으로 @vue/server-renderer를 통해 SSR + Hydration을 지원하므로, Nuxt 없이도 직접 구현해볼 수 있습니다.
