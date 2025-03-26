# Vue Ref 구현 상세 분석

## 개요

Vue의 `ref`는 반응성 시스템의 핵심 기능 중 하나다.  
이 글에서는 `ref`의 내부 구현과 동작 원리를 자세히 살펴본다.

## 1. Ref 생성 과정

```typescript
// 1. ref 호출
export function ref<T = any>(value: T): Ref<T> {
  return createRef(value, false);
}

// 2. createRef 실행
function createRef<T>(rawValue: T, shallow: boolean): Ref<T> {
  if (isRef(rawValue)) {
    return rawValue;
  }
  return new RefImpl(rawValue, shallow);
}
```

여기서 중요한 점은:

- `ref()` 호출 시 `createRef()`로 전달
- 이미 ref인 경우 그대로 반환 (중복 래핑 방지)
- 아닌 경우 `RefImpl` 인스턴스 생성

### 예시

```typescript
const count = ref(1); // RefImpl 인스턴스 생성
const count2 = ref(count); // 이미 ref이므로 그대로 반환
```

## 2. RefImpl 클래스

```typescript
class RefImpl<T = any> {
  _value: T;
  private _rawValue: T;
  dep: Dep = new Dep();
  public readonly [ReactiveFlags.IS_REF] = true;
  public readonly [ReactiveFlags.IS_SHALLOW]: boolean = false;

  constructor(value: T, isShallow: boolean) {
    this._rawValue = isShallow ? value : toRaw(value);
    this._value = isShallow ? value : toReactive(value);
    this[ReactiveFlags.IS_SHALLOW] = isShallow;
  }

  get value() {
    if (__DEV__) {
      this.dep.track({
        target: this,
        type: TrackOpTypes.GET,
        key: 'value',
      });
    } else {
      this.dep.track();
    }
    return this._value;
  }

  set value(newValue) {
    const oldValue = this._rawValue;
    const useDirectValue = this[ReactiveFlags.IS_SHALLOW] || isShallow(newValue) || isReadonly(newValue);
    newValue = useDirectValue ? newValue : toRaw(newValue);
    if (hasChanged(newValue, oldValue)) {
      this._rawValue = newValue;
      this._value = useDirectValue ? newValue : toReactive(newValue);
      if (__DEV__) {
        this.dep.trigger({
          target: this,
          type: TriggerOpTypes.SET,
          key: 'value',
          newValue,
          oldValue,
        });
      } else {
        this.dep.trigger();
      }
    }
  }
}
```

### Getter/Setter 동작

1. **Getter**

   ```typescript
   // 예시
   const count = ref(1);
   effect(() => {
     console.log(count.value); // getter 호출
   });
   ```

   - `value` 접근 시 `dep.track()` 호출
   - 개발 환경에서는 상세 정보 포함 (디버깅 용이)
   - 프로덕션 환경에서는 단순화된 추적 (성능 최적화)

2. **Setter**

   ```typescript
   // 예시
   count.value = 2; // setter 호출
   ```

   - 값 변경 시 `hasChanged`로 변경 여부 확인
   - 변경된 경우 `_rawValue`와 `_value` 업데이트
   - `dep.trigger()`로 의존성 실행

## 3. Dep 클래스

```typescript
export class Dep {
  version = 0;
  activeLink?: Link = undefined;
  subs?: Link = undefined;
  subsHead?: Link;
  map?: KeyToDepMap = undefined;
  key?: unknown = undefined;
  sc: number = 0;

  constructor(public computed?: ComputedRefImpl | undefined) {
    if (__DEV__) {
      this.subsHead = undefined;
    }
  }

  track(debugInfo?: DebuggerEventExtraInfo): Link | undefined {
    if (!activeSub || !shouldTrack || activeSub === this.computed) {
      return;
    }

    let link = this.activeLink;
    if (link === undefined || link.sub !== activeSub) {
      link = this.activeLink = new Link(activeSub, this);

      // 이중 연결 리스트로 의존성 관리
      if (!activeSub.deps) {
        activeSub.deps = activeSub.depsTail = link;
      } else {
        link.prevDep = activeSub.depsTail;
        activeSub.depsTail!.nextDep = link;
        activeSub.depsTail = link;
      }

      addSub(link);
    } else if (link.version === -1) {
      // 이전 실행에서 재사용 - 버전만 동기화
      link.version = this.version;

      // tail로 이동 처리
      if (link.nextDep) {
        const next = link.nextDep;
        next.prevDep = link.prevDep;
        if (link.prevDep) {
          link.prevDep.nextDep = next;
        }

        link.prevDep = activeSub.depsTail;
        link.nextDep = undefined;
        activeSub.depsTail!.nextDep = link;
        activeSub.depsTail = link;

        // head였다면 새로운 head 지정
        if (activeSub.deps === link) {
          activeSub.deps = next;
        }
      }
    }

    if (__DEV__ && activeSub.onTrack) {
      activeSub.onTrack(
        extend(
          {
            effect: activeSub,
          },
          debugInfo
        )
      );
    }

    return link;
  }

  trigger(debugInfo?: DebuggerEventExtraInfo): void {
    this.version++;
    globalVersion++;
    this.notify(debugInfo);
  }

  notify(debugInfo?: DebuggerEventExtraInfo): void {
    startBatch();
    try {
      if (__DEV__) {
        // 개발 환경에서 onTrigger 훅 실행
        for (let head = this.subsHead; head; head = head.nextSub) {
          if (head.sub.onTrigger && !(head.sub.flags & EffectFlags.NOTIFIED)) {
            head.sub.onTrigger(
              extend(
                {
                  effect: head.sub,
                },
                debugInfo
              )
            );
          }
        }
      }
      // 실제 의존성 실행 (역순)
      for (let link = this.subs; link; link = link.prevSub) {
        if (link.sub.notify()) {
          (link.sub as ComputedRefImpl).dep.notify();
        }
      }
    } finally {
      endBatch();
    }
  }
}
```

### Dep 클래스의 핵심 역할

1. **의존성 추적 (track)**

   ```typescript
   // Dep 클래스의 track 메서드
   track(debugInfo?: DebuggerEventExtraInfo): Link | undefined {
     // 1. 현재 실행 중인 effect 확인
     if (!activeSub || !shouldTrack || activeSub === this.computed) {
       return;
     }

     // 2. 새로운 링크 생성 또는 재사용
     let link = this.activeLink;
     if (link === undefined || link.sub !== activeSub) {
       link = this.activeLink = new Link(activeSub, this);

       // 3. 이중 연결 리스트로 의존성 관리
       if (!activeSub.deps) {
         activeSub.deps = activeSub.depsTail = link;
       } else {
         link.prevDep = activeSub.depsTail;
         activeSub.depsTail!.nextDep = link;
         activeSub.depsTail = link;
       }

       // 4. 의존성 등록
       addSub(link);
     }
   }
   ```

   ```typescript
   // 예시
   const count = ref(1);
   const doubled = computed(() => count.value * 2);
   const quadrupled = computed(() => doubled.value * 2);

   // 의존성 추적 과정
   // 1. count.value 접근 시
   effect(() => {
     console.log(count.value); // track 호출
     // activeSub = 현재 effect
     // link = 새로운 Link(현재 effect, count의 dep)
     // activeSub.deps = link
   });

   // 2. doubled.value 접근 시
   effect(() => {
     console.log(doubled.value); // track 호출
     // activeSub = 현재 effect
     // link = 새로운 Link(현재 effect, doubled의 dep)
     // activeSub.deps = link
   });
   ```

2. **의존성 실행 (trigger/notify)**

   ```typescript
   // Dep 클래스의 trigger 메서드
   trigger(debugInfo?: DebuggerEventExtraInfo): void {
     // 1. 버전 증가
     this.version++;
     globalVersion++;
     // 2. 의존성 실행
     this.notify(debugInfo);
   }

   // Dep 클래스의 notify 메서드
   notify(debugInfo?: DebuggerEventExtraInfo): void {
     startBatch();
     try {
       // 1. 개발 환경에서 onTrigger 훅 실행
       if (__DEV__) {
         for (let head = this.subsHead; head; head = head.nextSub) {
           if (head.sub.onTrigger && !(head.sub.flags & EffectFlags.NOTIFIED)) {
             head.sub.onTrigger(
               extend(
                 {
                   effect: head.sub,
                 },
                 debugInfo
               )
             );
           }
         }
       }
       // 2. 실제 의존성 실행 (역순)
       for (let link = this.subs; link; link = link.prevSub) {
         if (link.sub.notify()) {
           (link.sub as ComputedRefImpl).dep.notify();
         }
       }
     } finally {
       endBatch();
     }
   }
   ```

   ```typescript
   // 예시
   const count = ref(1);
   const doubled = computed(() => count.value * 2);
   const quadrupled = computed(() => doubled.value * 2);

   // 의존성 실행 과정
   count.value = 2; // trigger 호출

   // 1. count의 dep.trigger() 호출
   // - version 증가
   // - notify 호출

   // 2. notify 메서드에서
   // - startBatch() 호출
   // - computed 값 처리 (doubled, quadrupled)
   // - effect 처리
   // - endBatch() 호출
   ```

### 의존성 추적과 실행의 전체 흐름

1. **의존성 추적 (track)**

   ```typescript
   // 예시
   const count = ref(1);
   effect(() => {
     console.log(count.value); // 1. getter 호출
   });

   // track 메서드에서
   if (!activeSub || !shouldTrack || activeSub === this.computed) {
     return; // 2. 현재 실행 중인 effect 확인
   }

   let link = this.activeLink;
   if (link === undefined || link.sub !== activeSub) {
     link = this.activeLink = new Link(activeSub, this); // 3. 새로운 링크 생성

     if (!activeSub.deps) {
       activeSub.deps = activeSub.depsTail = link; // 4. 첫 번째 의존성
     } else {
       link.prevDep = activeSub.depsTail; // 5. 기존 의존성에 추가
       activeSub.depsTail!.nextDep = link;
       activeSub.depsTail = link;
     }

     addSub(link); // 6. 의존성 등록
   }
   ```

2. **의존성 실행 (trigger/notify)**

   ```typescript
   // 예시
   count.value = 2; // 1. setter 호출

   // trigger 메서드에서
   this.version++; // 2. 버전 증가
   globalVersion++;
   this.notify(debugInfo); // 3. 의존성 실행

   // notify 메서드에서
   startBatch(); // 4. 배치 시작
   try {
     // 5. 개발 환경에서 onTrigger 훅 실행
     if (__DEV__) {
       for (let head = this.subsHead; head; head = head.nextSub) {
         // ... onTrigger 훅 실행
       }
     }

     // 6. 실제 의존성 실행 (역순)
     for (let link = this.subs; link; link = link.prevSub) {
       if (link.sub.notify()) {
         (link.sub as ComputedRefImpl).dep.notify();
       }
     }
   } finally {
     endBatch(); // 7. 배치 종료
   }
   ```

이렇게 의존성 추적과 실행을 통해:

1. 효율적인 의존성 관리
2. 안정적인 업데이트 순서
3. 불필요한 재실행 방지
4. 메모리 최적화
   를 달성할 수 있다.

### 의존성 등록 (addSub)

```typescript
// Dep 클래스의 addSub 메서드
function addSub(link: Link): void {
  // 1. Dep의 subs 리스트에 추가
  if (!link.dep.subs) {
    link.dep.subs = link;
  } else {
    link.prevSub = link.dep.subs;
    link.dep.subs = link;
  }

  // 2. 개발 환경에서 subsHead 관리
  if (__DEV__) {
    if (!link.dep.subsHead) {
      link.dep.subsHead = link;
    } else {
      link.nextSub = link.dep.subsHead;
      link.dep.subsHead = link;
    }
  }
}
```

이 코드에서 중요한 점은:

1. **Dep의 subs 리스트 관리**

   ```typescript
   // 예시
   const count = ref(1);
   effect(() => {
     console.log(count.value); // 첫 번째 의존성
   });

   // addSub 호출 시
   if (!link.dep.subs) {
     link.dep.subs = link; // 첫 번째 의존성
   } else {
     link.prevSub = link.dep.subs; // 기존 의존성 앞에 추가
     link.dep.subs = link;
   }
   ```

   - 첫 번째 의존성은 `subs`에 직접 할당
   - 이후 의존성은 `prevSub`로 연결하여 리스트 구성
   - `notify` 메서드에서 `prevSub`로 역순 실행 가능

2. **의존성 실행 순서**

   ```typescript
   // 예시
   const count = ref(1);
   const doubled = computed(() => count.value * 2);
   effect(() => {
     console.log(doubled.value);
   });

   // 의존성 등록 순서
   count -> doubled -> effect

   // notify 메서드에서
   for (let link = this.subs; link; link = link.prevSub) {
     // effect -> doubled -> count 순서로 실행
   }
   ```

   - `addSub`으로 의존성 등록 시 순서 유지
   - `notify` 메서드에서 역순으로 실행하여 최신 값 사용

이렇게 `addSub`을 통해:

1. 의존성의 효율적인 관리
2. 개발 환경에서의 디버깅 지원
3. 안정적인 실행 순서 보장
   을 달성할 수 있다.

## 4. Effect와 배치 시스템

```typescript
export function startBatch(): void {
  batchDepth++;
}

export function endBatch(): void {
  if (--batchDepth > 0) return;

  // computed 값 처리
  if (batchedComputed) {
    let e: Subscriber | undefined = batchedComputed;
    batchedComputed = undefined;
    while (e) {
      e = e.next;
    }
  }

  // 일반 effect 처리
  while (batchedSub) {
    let e: Subscriber | undefined = batchedSub;
    batchedSub = undefined;
    while (e) {
      if (e.flags & EffectFlags.ACTIVE) {
        (e as ReactiveEffect).trigger();
      }
      e = e.next;
    }
  }
}
```

### 배치 시스템의 역할

1. **중첩 업데이트 처리**

   ```typescript
   // 예시
   const count = ref(1);
   effect(() => {
     count.value = 2; // 첫 번째 업데이트
     count.value = 3; // 두 번째 업데이트
   });
   // 한 번의 배치로 처리
   ```

   - 여러 업데이트를 하나의 배치로 묶음
   - 중첩된 업데이트를 올바르게 처리

2. **순서 보장**

   ```typescript
   // 예시
   const count = ref(1);
   const doubled = computed(() => count.value * 2);
   effect(() => {
     console.log(doubled.value);
   });
   count.value = 2;
   // 1. computed 값 처리
   // 2. effect 처리
   ```

   - computed 값 먼저 처리
   - 일반 effect 나중 처리
   - 역순으로 실행하여 의존성 순서 보장

3. **에러 처리**

   ```typescript
   // 예시
   const count = ref(1);
   effect(() => {
     try {
       count.value = 2;
     } catch (err) {
       console.error(err);
     }
   });
   ```

   - try-catch로 안전한 실행
   - 에러 발생 시 적절한 처리

## 🧠 핵심 요약

| 구분          | 설명           | 목적              |
| ------------- | -------------- | ----------------- |
| Ref           | 반응성 값 관리 | 값의 반응성 처리  |
| Dep           | 의존성 관리    | 의존성 추적/실행  |
| Track/Trigger | 변경 감지      | 의존성 등록/실행  |
| 배치          | 업데이트 관리  | 효율적인 업데이트 |

이런 구조를 통해 Vue는:

1. 효율적인 반응성 처리
2. 안정적인 상태 관리
3. 예측 가능한 동작
   을 달성하고 있다.
