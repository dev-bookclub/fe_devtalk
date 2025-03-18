라이브러리가 제공할 수 있는 세 가지 주요 자바스크립트 파일 유형 (ES 모듈, “클래식” 전역 변수 유형, CommonJS)
https://velog.io/@khjbest/%EC%8B%9C%EB%82%98%EB%B8%8C%EB%A1%9C-%EC%9E%90%EB%B0%94%EC%8A%A4%ED%81%AC%EB%A6%BD%ED%8A%B8-3%EC%A3%BC%EC%B0%A8-%EA%B0%80%EC%83%81-%EB%8F%94%EA%B3%BC-%EC%9B%B9-%EC%84%9C%EB%B2%84-%EA%B8%B0%EC%B4%88Express-%EC%84%9C%EB%B2%84%EB%A6%AC%EC%8A%A4#-commonjs%EC%99%80-es-modules%EC%9D%98-%EC%B0%A8%EC%9D%B4

  "main": "./dist/mini-query.umd.cjs",
  "module": "./dist/mini-query.js",
  "exports": {
    ".": {
      "import": "./dist/mini-query.js",
      "require": "./dist/mini-query.umd.cjs"
    }
  },

  Import Maps는 웹 브라우저에서 ES 모듈을 로드할 때, 모듈 이름과 URL 간의 매핑을 명시적으로 지정할 수 있는 기능입니다. 이를 통해 코드 내에서 사용하는 모듈의 "별칭"을 실제 파일 경로나 CDN 주소로 연결할 수 있습니다.

예를 들어, 다음과 같이 HTML 파일에 `<script type="importmap">` 태그를 사용하여 모듈 매핑을 정의할 수 있습니다:

```html
<script type="importmap">
{
  "imports": {
    "lodash": "https://cdn.jsdelivr.net/npm/lodash-es@4.17.21/lodash.js"
  }
}
</script>
```

위와 같이 설정하면, JavaScript 코드에서

```javascript
import _ from 'lodash';
```

라고 작성했을 때 브라우저는 `'lodash'`라는 모듈명을 설정된 URL(`https://cdn.jsdelivr.net/npm/lodash-es@4.17.21/lodash.js`)로 해석하여 해당 파일을 로드합니다.

“클래식” JS 파일
-> 아에 그냥 파일이 프로젝트에 포함되어있구나@@근데이제 umd.js확장자
사용 방법: <script src="whatever.js"></script>

✔️ 식별 방법:
웹사이트에 “CDN으로 사용하세요!”와 같은 큰 친절한 배너가 있는 경우
.umd.js 확장자
<script src=... 태그에 넣어보고 작동하는지 확인


ES 모듈
-> 이놈도 프로젝트에 파일이 있음. 근데 이제 .js파일임.
✔️ 식별 방법:
import나 export 문 찾기 (module.exports = ...가 아닌 경우, 그것은 CommonJS)
.mjs 확장자

✔️ 사용 방법:
의존성이 없는 경우, 코드에서 직접 import {whatever} from "./my-module.js" 사용
-> 파일의 정확한 위치를 직접 지정 (상대경로)
의존성이 있는 경우, importmap을 만들고 import {whatever} from "my-module" 사용
-> 미리 정의한 별칭을 사용해 외부 의존성이나 복잡한 경로를 보기쉽게 관리.
-> 의존성이 많은 라이브러리나 외부 모듈을 쉽게 업데이트하거나 교체할 수 있고, 코드 내에서 경로를 일일이 수정할 필요 없이 중앙에서 관리 가능

모듈을 어떻게 "찾느냐"의 차이.

- **의존성이 없는 경우:**  
  ```javascript
  import { whatever } from "./my-module.js";
  ```  
  이 방식은 현재 파일 기준의 상대 경로를 명시적으로 지정합니다. 즉, 코드 내에서 직접 해당 파일의 위치를 알려주므로, 해당 모듈이 프로젝트 내부에 있고 위치가 변하지 않을 때 사용합니다.

- **의존성이 있는 경우 (Import Map 사용):**  
  ```javascript
  import { whatever } from "my-module";
  ```  
  이 방식은 import map에 미리 정의된 매핑을 사용합니다.  
  예를 들어 HTML 파일에 아래와 같이 정의할 수 있습니다:
  ```html
  <script type="importmap">
  {
    "imports": {
      "my-module": "./node_modules/my-module/dist/index.js"
    }
  }
  </script>
  ```
  이렇게 하면, 코드에서는 "my-module"이라는 별칭만 사용해도, 브라우저가 import map을 참고하여 실제 모듈의 위치(예를 들어 외부 라이브러리나 의존성이 있는 모듈)를 찾아서 로드합니다.

esbuild나 다른 ES 모듈 번들러 사용
package.json의 "type": "module" (정확히 어떤 파일을 가리키는지는 명확하지 않음)
->요놈이 이제 표준화되었기때문에 디폴트값인걸로 알고있다
또는 download-esm을 사용하여 importmap 필요성 제거

CommonJS 모듈
✔️식별 방법:

코드에서 require()나 module.exports = ... 찾기
.cjs 확장자
package.json의 "type": "commonjs" (정확히 어떤 파일을 가리키는지는 명확하지 않음)

✔️ 사용 방법:

https://esm.sh를 사용하여 ES 모듈로 변환 (예: https://esm.sh/@atproto/oauth-client-browser@0.3.0)
어떻게든 빌드 사용 (??)