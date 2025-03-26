공식문서를 기반으로 Vue를 톺아보는 시간을 가져보려고 한다.

우선 Vue를 이해하는 데에 가장 기본이 되는 [**Reactivity**](https://ko.vuejs.org/guide/extras/reactivity-in-depth.html)에 대해 알아보자.

# 1. Reactivity란 무엇인가?

Vue의 핵심 철학 중 하나는 **‘데이터가 변경되면 자동으로 UI가 업데이트 된다’**는 거다.

Reactivity(반응성)는 상태 변화를 감지하고 의존성을 추적해, 필요한 부분만 다시 렌더링 하는 하나의 큰 시스템이다.

필자는 상태 변화 감지와 의존성 추적까지만 Reactivity 개념에 해당되는줄 알고 있었는데, 공부를 하다보니 ‘렌더링’까지 포함이 된 개념이었다.

상태가 변경될 때 개발자가 직접 DOM을 조작하는 상황을 생각해보자.

```tsx
let count = 0;

function updateDOM() {
  document.getElementById("count").textContent = count;
}

count++;
updateDOM();
```

이 상황을 Vue에서 똑같이 구현하면 아래처럼 할 수 있다. Vue 내부에서 count의 변경을 감지하고, 관련된 컴포넌트만 다시 렌더링 해준다.

```tsx
<script setup>
import { ref } from 'vue';
const count = ref(0);
</script>

<template>
  <p>{{ count }}</p>
  <button @click="count++">+</button>
</template>
```

이런 Vue의 Reactivity 시스템은 **Proxy 기반의 반응형 객체**와 **Effect 시스템**을 통해 작동한다.

1. 상태 변경 감지 (Proxy)
2. 변경된 값이 어떤 effect(render 함수)를 사용하는지 추적 (track)
3. 변경된 값이 있으면, 연결된 effect를 다시 실행하여 VNode를 새로 생성 (trigger)
4. Virtual DOM diffing을 거쳐 최소한의 실제 DOM 업데이트 수행

관련해서 좀 더 자세하게 알아보자.

# 2. Proxy 기반 구조

Vue3에서는 Proxy 기반으로 Reactivity 시스템이 구성되어 있다.

이전 Vue2에서는 Obejct.defineProperty 기반으로 되어 있었는데, 몇 가지 한계점이 있었다.

1. 새로운 속성을 동적으로 추가할 수 없음
2. 배열의 특정 변경 사항 감지 어려움
3. 중첩된 객체의 모든 속성을 수동으로 정의해야 함

Vue3에서는 reactive 객체에는 Proxy를 사용하고, ref에는 getter/setter를 사용한다. 아래는 동작에 대한 의사 코드이다.

```tsx
function reactive(obj) {
  return new Proxy(obj, {
    get(target, key) {
      track(target, key);
      return target[key];
    },
    set(target, key, value) {
      target[key] = value;
      trigger(target, key);
    },
  });
}
```

```tsx
function ref(value) {
  const refObject = {
    get value() {
      track(refObject, "value");
      return value;
    },
    set value(newValue) {
      value = newValue;
      trigger(refObject, "value");
    },
  };
  return refObject;
}
```

이 의사 코드를 보면 track()과 trigger()가 있는 걸 확인할 수 있다.

Vue의 Reactivity는 get() 시점에 의존성을 추적(track)하고, set() 시점에 다시 실행해야 할 함수를 트리거(trigger) 하는 구조로 되어 있다.

track() 내부에서 현재 실행 중인 이펙트가 있는지 확인한다. 존재하는 경우, 추적 중인 속성에 대한 구독자 이펙트(Set에 저장됨)를 조회하고 이펙트를 Set에 추가한다.

이펙트 구독은 전역 `WeakMap<target, Map<key, Set<effect>>>` 데이터 구조에 저장이 된다고 한다. 공식 문서에는 간단한 구현 예시만 있어서 WeekMap으로 어떻게 구현할 수 있을지 아래와 같이 생각해봤다.

```tsx
// ✅ 현재 실행 중인 이펙트
let activeEffect = null;
// ✅ 반응형 객체들의 의존성을 저장하는 맵
const targetMap = new WeakMap();

function track(target, key) {
  if (!activeEffect) return; // 실행 중인 이펙트가 없으면 추적할 필요 없음

  // ✅ 현재 target(객체)에 대한 의존성 맵 가져오기
  let depsMap = targetMap.get(target);
  if (!depsMap) {
    depsMap = new Map();
    targetMap.set(target, depsMap);
  }

  // ✅ 특정 key에 대한 의존성 집합 가져오기
  let deps = depsMap.get(key);
  if (!deps) {
    deps = new Set();
    depsMap.set(key, deps);
  }

  // ✅ 현재 실행 중인 effect를 등록하여 의존성 추가
  deps.add(activeEffect);
}
```

trigger() 내부에서 속성에 대한 구독자 이펙트를 다시 조회한다.

```tsx
function trigger(target, key) {
  const depsMap = targetMap.get(target);
  if (!depsMap) return;

  // ✅ 변경된 key에 연결된 effect들을 가져옴
  const deps = depsMap.get(key);
  if (!deps) return;

  // ✅ 등록된 모든 effect 다시 실행
  deps.forEach((effect) => effect());
}
```

이 코드에서 targetMap에는 어떤 값들이 어떤 형태로 저장될까? 아래 예시 상황으로 이해해보자.

count라는 반응형(reactive) 값을 변경하는 코드인데, track()과 trigger()를 거쳐 effect()가 실행된다.

```tsx
const state = reactive({ count: 0 });

effect(() => {
  console.log("Count changed:", state.count); // 실제로는 렌더링 함수가 들어감
});

state.count++;
```

동작 흐름을 자세히 나눠보면 이렇게 된다.

1. effect() 실행
   1. `console.log('Count changed:', state.count);` 실행
   2. 이때 `state.count`를 읽으면서 `Proxy`의 `get()`이 호출됨
   3. Vue 내부에서 `track()` 실행 → `count`를 읽고 있다는 걸 기억해둠
2. `state.count++` 실행
   1. `set()`이 호출됨 → `trigger()` 실행
   2. `count`를 의존하고 있는 `effect()`를 다시 실행

왜 effect()를 먼저 실행해야 하는지 궁금해 찾아보니 **이펙트 내부에서 어떤 반응형 값이 사용되고 있는지 의존성을 추적하기 위해** 먼저 실행되어야 한다고 한다.

내부적으로 effect()를 실행해 activeEffect에 저장하고, `state.count`를 읽을 때 get()이 호출되면서 track()이 실행되어 `state.count`가 현재 실행 중인 effect()와 연결되는 것이다.

track()이 실행되면 targetMap에는 아래처럼 데이터가 저장되고, `state.count++`가 실행되면 count와 연결된 effect()가 다시 실행된다.

```tsx
// ✅ track() 호출 후
{
  { count: 0 }: {  // target (reactive 객체)
    count: Set([effect])  // "count"를 읽은 effect 저장
  }
}

// ----------

// ✅ trigger() 호출 후
{
  { count: 1 }: {   // target (값이 변경됨)
    count: Set([effect])  // 여전히 effect가 유지됨
  }
}
```

이렇게 어떤 컴포넌트에서 어떤 상태를 사용했는지 기록을 하게되고, 그 결과 (1)불필요한 리렌더링을 방지할 수 있고, (2)상태가 변경된 컴포넌트만 다시 렌더링할 수 있게 되었다. 상태가 변경된 컴포넌트만 다시 렌더(VNode 생성)하기 때문에 diffing 비용을 최소화해 최적화된 렌더링을 수행할 수 있다고 한다.

# 3. ‘언제’ 다시 렌더링 할 것인가

Vue의 최적화 된 렌더링을 이해하기 위해 **scheduler** 옵션에 대해서도 알아보자.

scheduler는 effect()가 실행될 타이밍과 방식을 제어하는 옵션이다. 기본적으로 effect()는 반응형 상태가 변경될 때 즉시 실행되지만, scheduler를 이용하면 실행 시점을 지연시키거나 최적화할 수 있다.

```tsx
effect(
  () => {
    console.log("Count changed:", state.count);
  },
  {
    scheduler: (fn) => {
      setTimeout(fn, 1000); // 1초 후 실행
    },
  }
);

state.count++; // 즉시 실행되지 않고 1초 후 실행
state.count++; // 1초 후 실행될 때 최신 값으로 반영
```

`state.count++`를 실행하면 trigger()가 실행된다는 건 이미 위에서 여러 차례 이야기했다. 다만, 여기서는 effect()를 즉시 실행하는 대신 scheduler에서 실행을 제어해, 1초 후에 실행이 된다.

만약 1초 내에 count가 여러 번 변경된다면 가장 최신 값을 적용한다.

Vue 내부에서는 scheduler를 어떻게 사용하고 있을까?

Vue는 scheduler를 사용해 렌더링 최적화(Batching)를 수행하는데, 이는 상태가 여러 번 변경되더라도 한 번만 렌더링되도록 스케줄링 하는 역할을 한다.

아래 코드는 Vue에 있는 [queueJob](https://github.com/vuejs/core/blob/main/packages/runtime-core/src/scheduler.ts#L94)과 [flushJobs](https://github.com/vuejs/core/blob/main/packages/runtime-core/src/scheduler.ts#L209) 로직을 따라 간단하게 구현해본 것이다.

```tsx
let isFlushing = false;
const queue = new Set(); // ✅ 실행할 effect를 중복 없이 저장하는 큐

function queueJob(job) {
  queue.add(job); // ✅ effect 중복 실행 방지 (Set이기 때문)

  if (!isFlushing) {
    isFlushing = true;
    Promise.resolve().then(flushJobs); // ✅ MicroTask Queue에 추가
  }
}

function flushJobs() {
  queue.forEach((job) => job()); // ✅ 저장된 effect 실행
  queue.clear(); // ✅ 실행 완료 후 큐 초기화
  isFlushing = false;
}
```

Vue는 `Promise.resolve().then()`을 사용해서 비동기적으로 effect를 실행하도록 스케줄링하여, 같은 이벤트 루프 사이클(tick) 내에서 여러 번 상태가 변경되더라도 effect()가 한 번만 실행되도록 한다.

```tsx
effect(
  () => {
    console.log("Rendering:", state.count);
  },
  {
    scheduler: (fn) => queueJob(fn),
  }
);

state.count++; // 실행되지 않음
state.count++; // 실행되지 않음
```

이렇게 적용한다면 같은 이벤트 루프 사이클 내에서 여러 번 호출되었으나, queueJob()이 batch 처리하여 한 번만 실행한다.

# 4. ‘어떤 컴포넌트’를 다시 렌더링 할 것인가

Vue는 반응형 상태가 변경되었을 때, **해당 상태를 사용한 컴포넌트만 다시 렌더링**한다. 즉, 의존성을 추적하여 특정 컴포넌트만 업데이트할 수 있도록 설계되어 있다.

이는 기본적으로 부모가 리렌더링되면 자식도 리렌더링되는 React의 렌더링 방식과는 차이가 있다.

Vue는 어떻게 필요한 컴포넌트만 다시 렌더링할 수 있는 걸까?

그 이유는 크게 두 가지이다. 첫 번째, 패치 플래그(Patch Flags)를 사용해 어떤 속성이 변경되었는지 추적한다. 두 번째, 트리 플래트닝(Tree Flattening)을 통해 VNode를 최적화된 배열 구조로 변환하여 빠르게 비교(diffing)한다.

## 4-1. Patch Flags

Vue와 React 모두 Virtual DOM Diffing을 수행하는데, 이는 이전 렌더링 결과(VNode)와 새로운 렌더링 결과(VNode)를 비교(diff)해서 변경된 부분만 실제 DOM에 반영하는 것이다.

모든 속성을 비교하는 것은 비용이 크기 때문에 Vue에서는 템플릿을 컴파일할 때, 각 요소에 대해 어떤 데이터가 변경될 가능성이 있는지 미리 표시해둔다.

예를 들어 아래와 같은 템플릿 코드가 있다고 해보자.

```tsx
<div :class="{ active }"></div>
```

이 코드가 변환되면 아래와 같이 [패치 플래그](https://github.com/vuejs/core/blob/main/packages/shared/src/patchFlags.ts)가 추가된다.

```tsx
createElementVNode(
  "div",
  {
    class: _normalizeClass({ active: _ctx.active }),
  },
  null,
  2 /* CLASS */
);
```

마지막 인자 2가 패치 플래그이며, 이를 확인하고 Virtual DOM에서 클래스만 비교하고 다른 속성은 건너뛸 수 있다.

각 엘리먼트는 이런 플래그를 여러 개 가질 수 있고, 런타인 렌더러는 비트 연산을 사용하여 플래그를 확인해 어떤 작업을 수행해야 하는지 결정한다.

## 4-2. Tree Flattening

패치 플래그를 활용하면 변경된 부분만 비교할 수 있지만, VNode 트리 자체를 최적화하는 것도 중요하다. Vue는 이를 위해 트리 플래트닝(병합)을 수행한다.

```html
<template>
  <div>
    <p>{{ count }}</p>
    <span>고정된 텍스트</span>
  </div>
</template>
```

이 코드를 트리 플래트닝 없이 Virtual DOM 구조로 변환하면 아래처럼 되는데, 이러면 VNode 비교 시 트리를 재귀적으로 순회해야 한다. 그럼 깊은 구조일 수록 비교 비용이 증가하게 된다. 또한, 불필요한 정적 노드까지 비교 대상에 포함돼 비효율적이다.

```tsx
createVNode("div", null, [
  createVNode("p", null, count), // 동적 노드
  createVNode("span", null, "고정된 텍스트"), // 정적 노드
]);
```

이를 개선한 트리 플래트닝 방식으로 VNode 트리를 만들면 아래처럼 된다. 1차원 배열 구조로 만들어 재귀적 탐색을 할 필요가 없고, 정적 노드는 배열에서 제외해 비교 대상 수가 줄었다.

```tsx
const mergedVNodeArray = [
  createVNode("p", null, count), // 동적 노드만 포함
];
```

# 5. 마무리

이번에 알아보면서, Vue는 단순히 Virtual DOM을 활용하는 것이 아니라, Reactivity 시스템과 함께 렌더링을 최적화하는 구조를 가지고 있다는 걸 알게 되었다.

렌더링 메커니즘을 깊이 이해한 만큼, 이제는 Vue Devtools를 활용해 반응형 상태와 렌더링 트리를 직접 분석해보는 것이 중요하겠다고 느꼈다.

앞으로도 공식 문서와 GitHub 소스를 참고하며 Vue 내부 로직을 꾸준히 탐구하며, 프레임워크의 동작 원리를 제대로 이해하고 사용하는 개발자가 되어야겠다.

끝!

## 참고 글

- [Vue 공식문서 - 반응형 심화](https://ko.vuejs.org/guide/extras/reactivity-in-depth)
- [Vue 공식문서 - 렌더링 메커니즘](https://ko.vuejs.org/guide/extras/rendering-mechanism.html)
- [Proxy 디자인 패턴](https://patterns-dev-kr.github.io/design-patterns/proxy-pattern/)
- [MDN - Proxy 객체](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Proxy)
- [MDN - getter](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Functions/get#description)
- [MDN - setter](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Functions/set#description)
