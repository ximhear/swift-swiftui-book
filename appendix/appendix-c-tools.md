# 부록 C. 유용한 도구와 라이브러리

## 개발 도구

### Xcode 내장 도구
| 도구 | 용도 |
|------|------|
| Memory Graph Debugger | 메모리 누수, 순환 참조 탐지 |
| View Debugger | View 계층 시각화 |
| Instruments | 성능 프로파일링 (Time Profiler, Allocations, Leaks, SwiftUI) |
| Accessibility Inspector | 접근성 검증 |
| Network Inspector | 네트워크 요청 모니터링 |

### 서드파티 도구
| 도구 | 용도 |
|------|------|
| Charles Proxy | 네트워크 트래픽 분석 |
| Proxyman | macOS 전용 네트워크 디버거 |
| Reveal | 런타임 View 검사 (UIKit/SwiftUI) |
| SwiftLint | Swift 코드 스타일/린트 |
| SwiftFormat | 코드 포매팅 자동화 |

## 추천 라이브러리

### 아키텍처
| 라이브러리 | 설명 |
|-----------|------|
| [swift-composable-architecture](https://github.com/pointfreeco/swift-composable-architecture) | TCA — 합성 가능한 아키텍처 |
| [swift-dependencies](https://github.com/pointfreeco/swift-dependencies) | 의존성 주입 |
| [swift-perception](https://github.com/pointfreeco/swift-perception) | iOS 16 이하 @Observable 백포트 |

### 네트워킹
| 라이브러리 | 설명 |
|-----------|------|
| [Alamofire](https://github.com/Alamofire/Alamofire) | HTTP 네트워킹 |
| [Nuke](https://github.com/kean/Nuke) | 이미지 로딩/캐싱 |
| [Kingfisher](https://github.com/onevcat/Kingfisher) | 이미지 다운로드/캐싱 |

### UI
| 라이브러리 | 설명 |
|-----------|------|
| [SwiftUI-Introspect](https://github.com/siteline/SwiftUI-Introspect) | SwiftUI에서 UIKit 뷰 접근 |
| [Lottie](https://github.com/airbnb/lottie-ios) | 애니메이션 |
| [Charts](https://github.com/danielgindi/Charts) | 차트 (SwiftUI Charts 이전 버전용) |

### 테스트
| 라이브러리 | 설명 |
|-----------|------|
| [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) | 스냅샷 테스트 |
| [ViewInspector](https://github.com/nalexn/ViewInspector) | SwiftUI View 단위 테스트 |
| [swift-custom-dump](https://github.com/pointfreeco/swift-custom-dump) | 향상된 diff/dump |

### 유틸리티
| 라이브러리 | 설명 |
|-----------|------|
| [swift-algorithms](https://github.com/apple/swift-algorithms) | 추가 시퀀스 알고리즘 |
| [swift-collections](https://github.com/apple/swift-collections) | 추가 자료구조 |
| [swift-async-algorithms](https://github.com/apple/swift-async-algorithms) | 비동기 시퀀스 알고리즘 |

## Swift Package Manager 팁

```swift
// Package.swift에서 버전 지정
.package(url: "https://github.com/...",
         from: "1.0.0")          // 1.0.0 이상
.package(url: "https://github.com/...",
         exact: "1.2.3")         // 정확히 이 버전
.package(url: "https://github.com/...",
         .upToNextMajor(from: "2.0.0"))  // 2.x.x
```
