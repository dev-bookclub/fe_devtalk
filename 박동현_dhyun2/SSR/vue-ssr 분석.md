# Vue SSR 완벽 가이드: 서버 사이드 렌더링의 모든 것

## 목차

1. [SSR의 기본 개념과 장점](#1-ssr의-기본-개념과-장점)
2. [Vue SSR의 동작 원리](#2-vue-ssr의-동작-원리)
3. [createApp과 createSSRApp의 차이](#3-createapp과-createssrapp의-차이)
4. [하이드레이션 프로세스 상세 분석](#4-하이드레이션-프로세스-상세-분석)
5. [Vue 런타임과 렌더러 시스템](#5-vue-런타임과-렌더러-시스템)
6. [실제 구현 예시와 코드 분석](#6-실제-구현-예시와-코드-분석)
7. [상태 관리와 데이터 전달](#7-상태-관리와-데이터-전달)
8. [자주 묻는 질문과 답변](#8-자주-묻는-질문과-답변)

## 1. SSR의 기본 개념과 장점

### 1.1 SSR이란?

서버 사이드 렌더링(SSR)은 서버에서 HTML을 문자열로 렌더링하여 정적 마크업을 클라이언트 브라우저로 보내는 기술입니다. 이후 클라이언트에서 하이드레이션을 통해 완전한 대화형 앱으로 전환됩니다.

### 1.2 SSR의 주요 장점

1. **컨텐츠 도달 시간 단축**

   - JavaScript 다운로드 및 실행 대기 없이 즉시 콘텐츠 표시
   - 사용자가 완전히 렌더링된 페이지를 더 빨리 볼 수 있음
   - Core Web Vitals 측정 항목 개선

2. **서버 측 데이터 처리**

   - 초기 방문 시 서버에서 데이터 페치
   - 데이터베이스와의 더 빠른 연결
   - 클라이언트보다 더 빠른 데이터 접근

3. **SEO 최적화**

   - 검색 엔진이 완전히 렌더링된 페이지 크롤링 가능
   - 더 나은 검색 엔진 노출
   - 콘텐츠 인덱싱 개선

4. **사전 렌더링 (SSG)**
   - 빌드 프로세스에서 한 번만 렌더링
   - 서버 부하 감소
   - 더 빠른 응답 시간

## 2. Vue SSR의 동작 원리

### 2.1 renderToString의 동작

```typescript
function renderToString(input: App | VNode, context?: SSRContext): Promise<string>;
```

`renderToString`은 Promise를 반환하는데, 이는 다음과 같은 이유 때문입니다:

- 컴포넌트의 비동기 데이터 페칭 처리
- 대규모 앱의 렌더링 차단 방지
- 서버 리소스의 효율적 사용

### 2.2 SSRContext의 활용

```javascript
const ctx = {};
const html = await renderToString(app, ctx);

console.log(ctx.teleports);
```

SSRContext는 텔레포트와 같은 특수 기능을 위한 컨텍스트를 제공합니다.

### 2.3 기본 SSR 구현

```javascript
import express from 'express';
import { createSSRApp } from 'vue';
import { renderToString } from 'vue/server-renderer';

const server = express();

server.get('/', (req, res) => {
  const app = createSSRApp({
    data: () => ({ count: 1 }),
    template: `<button @click="count++">{{ count }}</button>`,
  });

  renderToString(app).then(html => {
    res.send(`
    <!DOCTYPE html>
    <html>
      <head>
        <title>Vue SSR 예제</title>
      </head>
      <body>
        <div id="app">${html}</div>
      </body>
    </html>
    `);
  });
});

server.listen(3000, () => {
  console.log('ready');
});
```

## 3. createApp과 createSSRApp의 차이

### 3.1 createApp의 구현

```typescript
export const createApp = ((...args) => {
  const app = ensureRenderer().createApp(...args);

  if (__DEV__) {
    injectNativeTagCheck(app);
    injectCompilerOptionsCheck(app);
  }

  const { mount } = app;
  app.mount = (containerOrSelector: Element | ShadowRoot | string): any => {
    const container = normalizeContainer(containerOrSelector);
    if (!container) return;

    const component = app._component;
    if (!isFunction(component) && !component.render && !component.template) {
      component.template = container.innerHTML;
    }

    if (container.nodeType === 1) {
      container.textContent = '';
    }
    const proxy = mount(container, false, resolveRootNamespace(container));
    if (container instanceof Element) {
      container.removeAttribute('v-cloak');
      container.setAttribute('data-v-app', '');
    }
    return proxy;
  };

  return app;
}) as CreateAppFunction<Element>;
```

### 3.2 createSSRApp의 특별한 점

```javascript
// app.js (서버와 클라이언트 간에 공유)
import { createSSRApp } from 'vue';

export function createApp() {
  return createSSRApp({
    data: () => ({ count: 1 }),
    template: `<button @click="count++">{{ count }}</button>`,
  });
}
```

`createSSRApp`은 하이드레이션 모드에서 앱 인스턴스를 생성하며, `createApp`과 동일한 사용법을 제공합니다.

## 4. 하이드레이션 프로세스 상세 분석

### 4.1 하이드레이션이란?

하이드레이션은 서버에서 렌더링된 정적 HTML을 클라이언트에서 동적인 Vue 애플리케이션으로 "활성화"하는 과정입니다.

### 4.2 하이드레이션 과정

1. **DOM 매칭**

   - 서버에서 렌더링된 HTML과 가상 DOM 트리 매칭
   - 이벤트 리스너 부착
   - 상태 복원

2. **이벤트 핸들러 연결**

   - 클릭 이벤트 등 사용자 상호작용 처리
   - 반응성 시스템 활성화

3. **상태 동기화**
   - 서버 상태와 클라이언트 상태 일치
   - 데이터 바인딩 설정

## 5. Vue 런타임과 렌더러 시스템

### 5.1 렌더러 생성 과정

```typescript
function ensureRenderer() {
  return renderer || (renderer = createRenderer<Node, Element | ShadowRoot>(rendererOptions));
}

export function createRenderer<HostNode = RendererNode, HostElement = RendererElement>(options: RendererOptions<HostNode, HostElement>): Renderer<HostElement> {
  return baseCreateRenderer<HostNode, HostElement>(options);
}
```

### 5.2 렌더러 옵션 상세

```typescript
const {
  insert: hostInsert, // DOM 노드 삽입
  remove: hostRemove, // DOM 노드 제거
  patchProp: hostPatchProp, // 속성(prop) 업데이트
  createElement: hostCreateElement, // 엘리먼트 생성
  createText: hostCreateText, // 텍스트 노드 생성
  createComment: hostCreateComment, // 주석 노드 생성
  setText: hostSetText, // 텍스트 내용 설정
  setElementText: hostSetElementText, // 엘리먼트 텍스트 설정
  parentNode: hostParentNode, // 부모 노드 찾기
  nextSibling: hostNextSibling, // 다음 형제 노드 찾기
  setScopeId: hostSetScopeId = NOOP, // 스코프 ID 설정
  insertStaticContent: hostInsertStaticContent, // 정적 컨텐츠 삽입
} = options;
```

## 6. 실제 구현 예시와 코드 분석

### 6.1 서버 사이드 코드

```javascript
// server.js
import { createApp } from './app.js';

server.get('/', (req, res) => {
  const app = createApp();
  renderToString(app).then(html => {
    res.send(`
      <!DOCTYPE html>
      <html>
        <head>
          <title>Vue SSR</title>
        </head>
        <body>
          <div id="app">${html}</div>
          <script src="/app.js"></script>
        </body>
      </html>
    `);
  });
});
```

### 6.2 클라이언트 사이드 코드

```javascript
// client.js
import { createApp } from './app';

const app = createApp();
app.mount('#app');
```

## 7. 상태 관리와 데이터 전달

### 7.1 서버-클라이언트 상태 전달

```javascript
// 서버
const app = createApp();
const state = JSON.stringify(app._state);
const html = await renderToString(app);

res.send(`
  <!DOCTYPE html>
  <html>
    <head>
      <title>Vue SSR</title>
      <script>window.__INITIAL_STATE__=${state}</script>
    </head>
    <body>
      <div id="app">${html}</div>
      <script src="/app.js"></script>
    </body>
  </html>
`);

// 클라이언트
const app = createApp();
if (window.__INITIAL_STATE__) {
  app._state = JSON.parse(window.__INITIAL_STATE__);
}
app.mount('#app');
```

### 7.2 이벤트 핸들러 연결 과정

1. 서버에서 렌더링된 HTML에는 이벤트 핸들러가 없음
2. 클라이언트에서 하이드레이션 시 이벤트 핸들러 부착
3. Vue의 반응성 시스템 활성화
4. 사용자 상호작용 가능

## 8. 자주 묻는 질문과 답변

### 8.1 createApp()으로 생성된 app 객체는 어떤 데이터가 되나요?

Q: `createApp()`으로 생성된 app 객체는 어떤 데이터가 되나요?

A: `createApp()`으로 생성된 app 객체는 다음과 같은 구조를 가집니다:

```javascript
const app = {
  _component: {
    data: () => ({ count: 1 }),
    template: `<button @click="count++">{{ count }}</button>`,
  },
  _container: null,
  _context: {
    app: null,
    config: { isNativeTag: fn, isCustomElement: fn },
    mixins: [],
    components: {},
    directives: {},
    provides: Object.create(null),
  },
  _uid: 0,
  _type: 0,
  mount: fn,
  unmount: fn,
  provide: fn,
  component: fn,
  directive: fn,
  use: fn,
  mixin: fn,
  config: { isNativeTag: fn, isCustomElement: fn },
};
```

이 객체는 Vue 애플리케이션의 핵심 인스턴스로, 컴포넌트, 설정, 플러그인 등을 관리합니다.

### 8.2 createSSRApp()의 하이드레이션 모드는 어떻게 작동하나요?

Q: `createSSRApp()`이 하이드레이션 모드로 작동하는 원리가 궁금합니다.

A: `createSSRApp()`은 다음과 같은 과정으로 하이드레이션을 수행합니다:

1. **하이드레이션 모드 설정**

```javascript
function createSSRApp(rootComponent, rootProps = null) {
  const app = createApp(rootComponent, rootProps);
  app._isHydrating = true; // SSR 모드 표시

  const originalMount = app.mount;
  app.mount = containerOrSelector => {
    const container = normalizeContainer(containerOrSelector);
    // 하이드레이션 로직...
    return originalMount(container, true);
  };

  return app;
}
```

2. **DOM 매칭 및 이벤트 핸들러 연결**

- 서버에서 렌더링된 HTML과 가상 DOM 트리 매칭
- 각 DOM 노드에 이벤트 핸들러 부착
- Vue의 반응성 시스템 활성화

### 8.3 Vue를 브라우저에서 로드하는 것은 어떤 의미인가요?

Q: Vue를 브라우저에서 로드한다는 것은 어떤 의미인가요? 바닐라 JS 청크와는 어떤 차이가 있나요?

A: Vue를 브라우저에서 로드하는 것은 다음과 같은 과정을 의미합니다:

1. **빌드 과정**

```javascript
// 원본 Vue 코드
const app = createApp({
  data() {
    return { count: 0 };
  },
});

// 빌드 후 변환된 코드
const app = (function () {
  const _createApp = Vue.createApp;
  const _data = { count: 0 };
  return _createApp({
    setup() {
      return _data;
    },
  });
})();
```

2. **런타임 로드 과정**

```html
<!-- 1. Vue 런타임 라이브러리 로드 -->
<script src="vue.runtime.js"></script>

<!-- 2. 빌드된 애플리케이션 코드 로드 -->
<script src="app.built.js"></script>
```

3. **실행 과정**

- Vue 런타임이 빌드된 코드를 읽음
- 변환된 JS 코드를 실행
- 반응성, 가상DOM 등의 기능 제공

바닐라 JS 청크와의 차이점:

- 단순한 바닐라 JS는 Vue의 핵심 기능(반응성, 컴포넌트 시스템 등)이 없음
- Vue 런타임은 이러한 핵심 기능을 제공하는 프레임워크 코어를 포함
- 빌드된 코드는 Vue 런타임이 이해할 수 있는 형태로 변환됨

### 8.4 정적 HTML이 어떻게 이벤트와 연결되나요?

Q: 서버에서 보내는 정적 HTML이 어떻게 이벤트와 연결되나요?

A: 정적 HTML과 이벤트 연결은 다음과 같은 과정으로 이루어집니다:

1. **서버 사이드 렌더링**

```javascript
// 서버에서 HTML 생성
const html = await renderToString(app);
```

2. **클라이언트 사이드 하이드레이션**

```javascript
// 클라이언트에서
const app = createSSRApp({
  data: () => ({ count: 1 }),
  template: `<button @click="count++">{{ count }}</button>`,
});

// 하이드레이션 과정
app.mount('#app'); // 이 과정에서 이벤트 핸들러가 부착됨
```

3. **이벤트 핸들러 연결 과정**

- 서버에서 렌더링된 HTML에는 이벤트 핸들러가 없음
- 클라이언트에서 하이드레이션 시 이벤트 핸들러 부착
- Vue의 반응성 시스템 활성화
- 사용자 상호작용 가능

### 8.5 서버 상태는 어떻게 클라이언트로 전달되나요?

Q: 서버의 상태는 어떻게 클라이언트로 전달되나요?

A: 서버 상태는 다음과 같은 방식으로 클라이언트로 전달됩니다:

1. **서버에서 상태 직렬화**

```javascript
// 서버
const app = createApp();
const state = JSON.stringify(app._state);
const html = await renderToString(app);

res.send(`
  <!DOCTYPE html>
  <html>
    <head>
      <script>window.__INITIAL_STATE__=${state}</script>
    </head>
    <body>
      <div id="app">${html}</div>
    </body>
  </html>
`);
```

2. **클라이언트에서 상태 복원**

```javascript
// 클라이언트
const app = createApp();
if (window.__INITIAL_STATE__) {
  app._state = JSON.parse(window.__INITIAL_STATE__);
}
app.mount('#app');
```

이렇게 전달된 상태는 하이드레이션 과정에서 Vue의 반응성 시스템에 의해 관리됩니다.

### 8.6 SSR 상태 관리의 보안과 구현 상세

Q: Vue SSR에서 상태를 클라이언트로 전달할 때 보안 문제는 없나요? 실제로는 어떻게 구현되나요?

A: Vue SSR의 상태 관리에는 몇 가지 중요한 고려사항이 있습니다:

1. **보안 위험**

```javascript
// ❌ 위험한 방식
<script>window.__INITIAL_STATE__=${state}</script>
```

- 사용자가 직접 URL에 접근하면 상태 데이터를 볼 수 있음
- 민감한 정보가 노출될 수 있음
- XSS 공격에 취약할 수 있음

2. **Vue의 실제 구현 방식**

```javascript
// ✅ Vue의 실제 구현
// 1. 서버에서 상태 직렬화
const state = {
  // 민감하지 않은 초기 상태만 포함
  publicState: {
    user: {
      name: 'John',
      role: 'user',
    },
  },
};

// 2. 상태를 HTML에 숨김
const html = `
  <script>
    window.__INITIAL_STATE__ = ${JSON.stringify(state)}
  </script>
  <div id="app">${appHtml}</div>
`;

// 3. 클라이언트에서 상태 복원
const app = createApp();
if (window.__INITIAL_STATE__) {
  // 상태를 Vue의 반응성 시스템에 바인딩
  Object.assign(app._state, window.__INITIAL_STATE__);
}
```

3. **보안을 위한 모범 사례**

```javascript
// 1. 상태 필터링
const serializeState = state => {
  const publicState = {
    // 공개해도 되는 상태만 선택
    user: {
      name: state.user.name,
      role: state.user.role,
    },
  };
  return JSON.stringify(publicState);
};

// 2. XSS 방지
const escapeHtml = unsafe => {
  return unsafe.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#039;');
};

// 3. 상태 전달
const html = `
  <script>
    window.__INITIAL_STATE__ = ${serializeState(state)}
  </script>
  <div id="app">${escapeHtml(appHtml)}</div>
`;
```

4. **상태 바인딩 시점**

```javascript
// 1. 앱 생성 시점
const app = createApp({
  setup() {
    // 서버 상태를 ref로 변환
    const state = ref(window.__INITIAL_STATE__);

    // 상태 업데이트 시 반응성 유지
    const updateState = newState => {
      state.value = newState;
    };

    return { state, updateState };
  },
});

// 2. 컴포넌트에서 사용
const MyComponent = {
  setup() {
    const { state } = inject('appState');

    // 상태 변경 시 반응성 동작
    watch(
      () => state.value,
      newState => {
        console.log('State changed:', newState);
      }
    );
  },
};
```

5. **상태 전달 방식의 대안**

```javascript
// 1. API 엔드포인트 사용
// 서버
app.get('/api/initial-state', (req, res) => {
  // 인증된 사용자에게만 상태 제공
  if (isAuthenticated(req)) {
    res.json(getInitialState(req.user));
  } else {
    res.status(401).send('Unauthorized');
  }
});

// 클라이언트
const app = createApp();
if (isAuthenticated()) {
  fetch('/api/initial-state')
    .then(res => res.json())
    .then(state => {
      app._state = state;
      app.mount('#app');
    });
}
```

이러한 방식으로 구현하면:

- 민감한 데이터 보호
- XSS 공격 방지
- 상태의 반응성 유지
- 사용자별 맞춤 상태 제공

이 가능해집니다.

## 결론

Vue SSR은 복잡한 시스템이지만, 잘 설계된 아키텍처를 통해 서버 사이드 렌더링과 클라이언트 사이드 하이드레이션을 효과적으로 구현합니다. 주요 포인트를 정리하면:

1. **서버 렌더링**: `renderToString`을 통한 HTML 생성
2. **하이드레이션**: `createSSRApp`을 통한 클라이언트 활성화
3. **상태 관리**: 서버-클라이언트 간 상태 전달
4. **성능 최적화**: 초기 로딩 시간 단축 및 SEO 개선

이러한 기능들이 조화롭게 작동하여 현대적인 웹 애플리케이션의 요구사항을 충족시킵니다.

## 참고 자료

- [Vue.js 공식 SSR 가이드](https://vuejs.org/guide/scaling-up/ssr.html)
- [Vue.js GitHub 저장소](https://github.com/vuejs/core)
