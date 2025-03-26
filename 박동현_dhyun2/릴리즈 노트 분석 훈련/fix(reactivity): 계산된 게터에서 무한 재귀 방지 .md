# Vue 3.5 RC1 - Reactivity 무한 재귀 버그 수정

## 개요

Vue 3.5 RC1에서는 중요한 반응성 관련 버그가 수정되었다.  
기존에는 정상적으로 작동하던 `ref`와 `reactive` 조합이  
Vue 3.5에서 **무한 재귀 호출**로 인해 `Maximum call stack size exceeded` 에러를 유발하게 되었다.  
이 글에서는 그 원인과 해결 과정을 Vue 내부 동작과 함께 분석한다.

---

## 문제 상황

Vue 공식 CHANGELOG에서도 해당 문제는 다음과 같이 명시되어 있다.

> [reactivity: avoid infinite recursion when mutating ref wrapped in reactive](https://github.com/vuejs/core/blob/main/CHANGELOG.md#350-rc1-2024-08-29)  
> [commit 313e4bf](https://github.com/vuejs/core/commit/313e4bf))
> Closes [#11696](https://github.com/vuejs/core/issues/11696)

---

## 재현 코드

```vue
<script setup>
import { reactive, ref, effect } from 'vue';

const a = reactive(ref(1));

effect(() => {
  console.log(a.value);
});

a.value++;
</script>

<template>
  <button>hi</button>
</template>
```

---

## 내부 동작 설명

Vue에서 `reactive()`는 내부적으로 `Proxy`를 생성하고, 이를 조작할 수 있는 **핸들러 클래스**를 지정한다.  
가장 일반적인 경우, Vue는 `BaseReactiveHandler`를 기반으로 한 `MutableReactiveHandler` 를 사용한다.

`MutableReactiveHandler`는 `Proxy`의 `set()` 을 다음과 같이 오버라이드한다:

### set 메서드 구조

```ts
set(
  target: Record<string | symbol, unknown>,
  key: string | symbol,
  value: unknown,
  receiver: object
): boolean
```

### 기존 구현 방식

```ts
const result = Reflect.set(target, key, value, receiver);
```

여기서 중요하게 볼 인자는 4번째 `receiver`이다. 해당 인자는 setter가 실행될 때 this로 사용할 값을 전달한다.

이때 문제는 `receiver`가 `ref` 객체일 경우, 내부 `setter`에서 `this`가 Proxy로 바뀌어버린다는 점이다.  
`ref`는 내부적으로 다음과 같은 getter/setter 구조를 가진다:

```ts
{
  get value() {
    track()
    return _value
  },
  set value(newVal) {
    _value = newVal
    trigger()
  }
}
```

만약 `this`가 `ref`가 아닌 Proxy라면 → `this._value`가 정의되지 않아 동작이 꼬이게 된다.  
그리고 내부에서 다시 reactive 처리가 일어나면서 **무한 재귀**가 발생하는 것이다.

---

## 문제가 되는 케이스 예시

```ts
import { reactive, ref, effect } from 'vue';

const a = reactive(ref(1));

effect(() => {
  console.log(a.value); // 이걸 반응형으로 감시함
});

a.value++;
```

`Maximum call stack size exceeded`이 발생하게 된다.

1. effect(() => console.log(a.value)) 실행
   -> a.value에 의존성을 등록하여 a.value가 바뀌면 effect가 다시 실행되어야함
2. a.value++ 실행
   -> set a.value = 2 가 실행됨 이제 proxy의 set()트랩이 실행되고, vue 내부에서 trigger()가 호출됨
3. trigger()가 종속된 effect 재실행
4. effect안에 a.value가 있음
   -> 다시 getter 부르고 끝나야하지만, vue 내부 로직이 깨졌기 때문에 setter를 또 트리거

> Q. 왜 setter를 또 트리거 하나?
> this가 ref가 아니라 Proxy가 돼서, trigger()가 ref가 아닌걸 트리거하거나, 값 비교가 꺠져서 항상 바뀌었다고 인식됨.
> getter가 내부에서 Proxy객체의 .value를 다시 평가하게되고, 이 과정에서 proxy set트랩에 걸려서 setter가 또 호출되는 형식

---

## 해결 방법

Vue 팀은 `MutableReactiveHandler` 내부에서 `Reflect.set()` 호출 시  
다음처럼 **receiver의 정확한 컨텍스트**를 보장하도록 수정했다:

```ts
const result = Reflect.set(target, key, value, isRef(target) ? target : receiver);
```

즉, `target`이 `ref`라면 → `receiver`로 `target` 자체를 넘겨서  
ref 내부의 setter에서 `this === ref`가 되도록 보장해준다.

---

## 핵심 요약

| 항목      | 설명                                                                      |
| --------- | ------------------------------------------------------------------------- |
| 문제 버전 | Vue 3.5 RC 이전                                                           |
| 증상      | `ref`를 `reactive`로 감쌌을 때 값 변경 시 무한 루프                       |
| 원인      | Proxy의 `set` 내부에서 ref의 `this` 컨텍스트가 깨짐                       |
| 해결      | `Reflect.set()`에서 `receiver`를 `isRef(target)`인 경우 `target`으로 지정 |
| 상태      | Vue 3.5 RC1에서 패치 완료                                                 |

---
