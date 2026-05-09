# Chapter 14. 성능 프로파일링과 최적화

> 성능 최적화의 첫 번째 규칙은 **"측정 먼저, 최적화 나중"**입니다. 느리다고 느끼는 것과 실제로 느린 것은 다릅니다. 이 장에서는 SwiftUI 앱의 성능 병목을 정확히 찾아내고, 체계적으로 최적화하는 방법을 다룹니다.

---

## 14.1 SwiftUI 성능 병목 찾기

### body 재호출 횟수 모니터링

```swift
struct PerformanceMonitor: ViewModifier {
    let label: String
    @State private var renderCount = 0
    
    func body(content: Content) -> some View {
        let _ = Self._printChanges()
        let _ = {
            renderCount += 1
            if renderCount > 10 {
                print("⚠️ \(label): \(renderCount)회 렌더링")
            }
        }()
        
        content
    }
}

extension View {
    func monitorPerformance(
        _ label: String
    ) -> some View {
        modifier(PerformanceMonitor(label: label))
    }
}

// 사용
struct MyView: View {
    var body: some View {
        ExpensiveView()
            .monitorPerformance("ExpensiveView")
    }
}
```

### 불필요한 body 재호출의 흔한 원인

```swift
// ❌ 원인 1: body 안에서 객체 생성
struct BadView: View {
    var body: some View {
        // DateFormatter를 매번 생성!
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return Text(formatter.string(from: Date.now))
    }
}

// ✅ static 또는 외부로 분리
struct GoodView: View {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()
    
    var body: some View {
        Text(Self.formatter.string(from: Date.now))
    }
}
```

```swift
// ❌ 원인 2: 매번 새 배열/딕셔너리 생성
struct BadListView: View {
    let items: [Item]
    
    var body: some View {
        // sorted()가 매 렌더링마다 호출됨
        List(items.sorted(by: { $0.name < $1.name })) {
            item in Text(item.name)
        }
    }
}

// ✅ 계산 결과를 캐시
struct GoodListView: View {
    let items: [Item]
    
    private var sortedItems: [Item] {
        items.sorted(by: { $0.name < $1.name })
    }
    
    var body: some View {
        // 더 좋은 방법: 상위에서 정렬된 배열을 전달
        List(sortedItems) { item in
            Text(item.name)
        }
    }
}
```

---

## 14.2 Lazy 컨테이너 최적화

### LazyVStack vs VStack

```swift
// ❌ VStack: 모든 자식을 즉시 생성
struct BadScrollView: View {
    var body: some View {
        ScrollView {
            VStack {
                ForEach(0..<10000, id: \.self) { i in
                    ExpensiveRow(index: i)
                    // 10000개 Row가 모두 즉시 생성됨!
                }
            }
        }
    }
}

// ✅ LazyVStack: 보이는 것만 생성
struct GoodScrollView: View {
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(0..<10000, id: \.self) { i in
                    ExpensiveRow(index: i)
                    // 화면에 보이는 Row만 생성됨
                }
            }
        }
    }
}
```

### List 성능 최적화

```swift
struct OptimizedList: View {
    let items: [LargeItem]
    
    var body: some View {
        List {
            ForEach(items) { item in
                // ✅ 가벼운 Row View 사용
                LightweightRow(item: item)
            }
        }
        .listStyle(.plain)
        // .listStyle(.insetGrouped)보다
        // .plain이 성능이 좋음 (그림자/라운드 없음)
    }
}

// Row View는 최대한 가볍게
struct LightweightRow: View {
    let item: LargeItem
    
    var body: some View {
        HStack {
            // ✅ AsyncImage에 캐시 활용
            CachedAsyncImage(url: item.thumbnailURL)
                .frame(width: 50, height: 50)
            
            VStack(alignment: .leading) {
                Text(item.title)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
```

---

## 14.3 이미지/미디어 처리 최적화

### 이미지 다운샘플링

🟡 중급

```swift
extension UIImage {
    /// 필요한 크기로 다운샘플링하여 메모리 절약
    static func downsample(
        at url: URL,
        to pointSize: CGSize,
        scale: CGFloat = UITraitCollection.current.displayScale
    ) -> UIImage? {
        let imageSourceOptions = [
            kCGImageSourceShouldCache: false
        ] as CFDictionary
        
        guard let imageSource = CGImageSourceCreateWithURL(
            url as CFURL, imageSourceOptions)
        else { return nil }
        
        let maxDimension = max(
            pointSize.width, pointSize.height) * scale
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ] as CFDictionary
        
        guard let downsampledImage =
            CGImageSourceCreateThumbnailAtIndex(
                imageSource, 0, downsampleOptions)
        else { return nil }
        
        return UIImage(cgImage: downsampledImage)
    }
}
```

### 비동기 이미지 로딩 패턴

```swift
struct ThumbnailView: View {
    let url: URL
    let size: CGSize
    
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(.gray.opacity(0.2))
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: url) {
            // 백그라운드에서 다운샘플링
            image = await Task.detached(priority: .utility) {
                UIImage.downsample(at: url, to: size)
            }.value
        }
    }
}
```

---

## 14.4 Instruments 활용 실전 가이드

### SwiftUI 전용 Instrument

Xcode의 Instruments에는 **SwiftUI** 템플릿이 있습니다:

1. Product → Profile (⌘I)
2. **SwiftUI** 템플릿 선택
3. 세 가지 트랙 확인:
   - **View Body**: body가 호출된 횟수와 시간
   - **View Properties**: 상태 변경 추적
   - **Core Animation Commits**: 실제 렌더링 커밋

### 주요 확인 포인트

| 지표 | 정상 범위 | 문제 신호 |
|------|-----------|-----------|
| body 호출 시간 | < 1ms | > 5ms |
| 프레임 드롭 | 0 | 연속 드롭 |
| 메모리 사용량 | 안정적 | 계속 증가 |
| 힙 할당 빈도 | 낮음 | 스크롤 시 급증 |

### Time Profiler로 병목 찾기

```text
1. Instruments → Time Profiler 선택
2. 앱에서 느린 동작 반복 수행
3. Call Tree에서 가장 시간을 많이 쓰는 함수 확인
4. Invert Call Tree 옵션으로 리프 함수부터 확인
5. Hide System Libraries로 내 코드만 필터링
```

### 실전 최적화 체크리스트

```markdown
□ LazyVStack/LazyHStack을 사용하는가?
□ 큰 이미지를 다운샘플링하는가?
□ body 안에서 무거운 계산을 하지 않는가?
□ ForEach에 안정적인 id를 사용하는가?
□ 불필요한 상태 의존성이 없는가?
□ @Observable의 세밀한 추적을 활용하는가?
□ drawingGroup()이 필요한 복잡한 그래픽이 있는가?
□ 네트워크 이미지에 캐싱을 적용하는가?
□ 긴 리스트에 페이지네이션을 적용하는가?
□ 무거운 작업을 백그라운드로 분리했는가?
```

---

## 14.5 Instruments 실전 워크스루

실제 현장에서 자주 발생하는 **"스크롤 시 프레임 드롭"** 시나리오를 통해 Instruments 분석의 전체 흐름을 살펴봅니다.

### 문제 상황: 느린 리스트 스크롤

다음은 연락처 목록을 표시하는 뷰입니다. 스크롤 시 뚝뚝 끊기는 현상이 발생합니다.

```swift
// ❌ 문제 코드: 스크롤 시 프레임 드롭 발생
struct ContactListView: View {
    @State private var contacts: [Contact] = Contact.sampleData()
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredContacts) { contact in
                        ContactRow(contact: contact)
                        Divider()
                    }
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("연락처")
        }
    }
    
    // ⚠️ body가 재호출될 때마다 정렬 + 필터링 수행
    var filteredContacts: [Contact] {
        let sorted = contacts.sorted {
            $0.name.localizedCompare($1.name) == .orderedAscending
        }
        if searchText.isEmpty {
            return sorted
        }
        return sorted.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
}

struct ContactRow: View {
    let contact: Contact
    
    var body: some View {
        HStack(spacing: 12) {
            // ⚠️ 매 렌더링마다 DateFormatter 생성
            let formatter = DateFormatter()
            let _ = formatter.dateStyle = .medium
            let _ = formatter.locale = Locale(identifier: "ko_KR")
            
            Circle()
                .fill(contact.color)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(contact.name.prefix(1)))
                        .font(.headline)
                        .foregroundStyle(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.name)
                    .font(.body)
                Text("마지막 연락: \(formatter.string(from: contact.lastContacted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // ⚠️ body 안에서 무거운 연산
            Text(relativeTimeString(from: contact.lastContacted))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // ⚠️ 매번 Calendar 연산 수행
    func relativeTimeString(from date: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents(
            [.day, .hour, .minute],
            from: date,
            to: Date.now
        )
        if let day = components.day, day > 0 {
            return "\(day)일 전"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)시간 전"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)분 전"
        }
        return "방금"
    }
}
```

### 1단계: SwiftUI Instrument로 body 호출 확인

Xcode에서 **Product → Profile (⌘I)** 을 실행한 뒤 **SwiftUI** 템플릿을 선택합니다.

```text
1. SwiftUI 템플릿으로 프로파일링 시작
2. 앱에서 연락처 리스트를 위아래로 빠르게 스크롤
3. 녹화를 멈추고 View Body 트랙을 확인

관찰 결과:
- ContactRow.body 호출 1회당 평균 8~12ms 소요
- 스크롤 중 초당 60회 이상 body 호출 발생
- 16.6ms(60fps) 예산 중 body만으로 거의 소진
```

**View Body** 트랙에서 `ContactRow`를 클릭하면 호출 횟수와 평균 소요 시간을 확인할 수 있습니다. 정상적인 body는 1ms 미만이어야 합니다. 8~12ms는 명백한 문제 신호입니다.

### 2단계: Time Profiler로 핫 패스(Hot Path) 확인

SwiftUI Instrument에서 문제를 발견했으니, 이제 정확히 **어떤 코드**가 시간을 잡아먹는지 확인합니다.

```text
1. Instruments → Time Profiler 추가 (+ 버튼)
2. 동일하게 스크롤 동작 수행
3. Call Tree 옵션 설정:
   ☑ Invert Call Tree
   ☑ Hide System Libraries
   ☑ Separate by Thread (Main Thread만 확인)

핫 패스 결과 (예시):
Weight    Symbol
------    ------
35.2%     DateFormatter.init()
24.1%     DateFormatter.string(from:)
18.7%     Array.sorted(by:)
 8.3%     Calendar.dateComponents(_:from:to:)
```

`DateFormatter` 생성이 전체 시간의 35%를 차지합니다. `sorted()`도 매번 전체 배열을 정렬하고 있습니다.

### 3단계: Allocations로 메모리 증가 패턴 확인

```text
1. Instruments → Allocations 추가
2. 스크롤을 30초간 수행
3. Statistics 뷰에서 Growth 컬럼을 확인

관찰 결과:
- NSDateFormatter 객체가 수백 개 할당 후 해제 반복
- 스크롤 중 Transient 할당이 급증 → GC 압박 → 추가 프레임 드롭
- "Mark Generation" 버튼으로 스크롤 전후 비교 가능
```

**Mark Generation** 기능을 사용하면 특정 시점 사이에 생성된 객체만 필터링할 수 있습니다. 스크롤 시작 전에 한 번, 스크롤 종료 후에 한 번 마크하면 스크롤 중 발생한 할당만 볼 수 있습니다.

### 4단계: 수정 코드

분석 결과를 바탕으로 세 가지 문제를 수정합니다.

```swift
// ✅ 수정 1: static DateFormatter + RelativeDateTimeFormatter
struct ContactRow: View {
    let contact: Contact
    
    // DateFormatter를 static으로 한 번만 생성
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.locale = Locale(identifier: "ko_KR")
        return f
    }()
    
    // RelativeDateTimeFormatter 활용
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.unitsStyle = .abbreviated
        return f
    }()
    
    var body: some View {
        HStack(spacing: 12) {
            ContactAvatar(name: contact.name, color: contact.color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.name)
                    .font(.body)
                Text("마지막 연락: \(Self.dateFormatter.string(from: contact.lastContacted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(Self.relativeFormatter.localizedString(
                for: contact.lastContacted,
                relativeTo: Date.now
            ))
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// ✅ 수정 2: 아바타를 별도 View로 분리 (재호출 범위 축소)
struct ContactAvatar: View {
    let name: String
    let color: Color
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 44, height: 44)
            .overlay(
                Text(String(name.prefix(1)))
                    .font(.headline)
                    .foregroundStyle(.white)
            )
    }
}

// ✅ 수정 3: 정렬 결과 캐싱 + 검색 최적화
struct ContactListView: View {
    @State private var contacts: [Contact] = Contact.sampleData()
    @State private var searchText = ""
    
    // 정렬은 데이터가 바뀔 때만 수행
    private var sortedContacts: [Contact] {
        contacts.sorted {
            $0.name.localizedCompare($1.name) == .orderedAscending
        }
    }
    
    // 필터링만 검색어 변경 시 수행
    private var filteredContacts: [Contact] {
        guard !searchText.isEmpty else { return sortedContacts }
        return sortedContacts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredContacts) { contact in
                        ContactRow(contact: contact)
                        Divider()
                    }
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("연락처")
        }
    }
}
```

> **더 나아가기**: 데이터가 수천 건 이상이라면 `sortedContacts`를 `@State`로 캐싱하고, `contacts`가 변경될 때만 `.onChange`에서 정렬을 수행하는 방법도 고려합니다.

### 수정 후 프로파일링 결과

```text
수정 전                    수정 후
─────────────────────    ─────────────────────
body 평균: 8~12ms        body 평균: 0.3~0.8ms
프레임 드롭: 다수          프레임 드롭: 0
DateFormatter 할당: 수백   DateFormatter 할당: 1 (static)
스크롤 Transient 할당: 높음  스크롤 Transient 할당: 낮음
```

---

## 14.6 drawingGroup()과 GPU 가속

🔴 고급

### drawingGroup()의 동작 원리

SwiftUI는 기본적으로 **Core Animation** 레이어 트리를 통해 뷰를 렌더링합니다. 각 뷰가 개별 CALayer를 가지므로, 뷰 수가 많아지면 레이어 합성(compositing) 비용이 급격히 증가합니다.

`drawingGroup()`은 해당 뷰 하위의 모든 드로잉 명령을 **Metal 오프스크린 버퍼**에 먼저 래스터라이즈한 뒤, 결과 텍스처 하나만 레이어 트리에 올립니다. 개별 CALayer가 하나로 플래트닝(flattening)되므로 합성 비용이 대폭 줄어듭니다.

```text
drawingGroup() 없이:
  CALayer(Circle 1)
  CALayer(Circle 2)
  ...
  CALayer(Circle 100)
  → 100개 레이어를 GPU에서 개별 합성

drawingGroup() 적용:
  Metal 오프스크린 → 단일 텍스처
  CALayer(텍스처 1개)
  → 1개 레이어만 합성
```

### 사용해야 하는 경우 vs 사용하면 안 되는 경우

| 사용하면 좋은 경우 | 사용하면 안 되는 경우 |
|---|---|
| 수십~수백 개의 겹치는 도형/그래디언트 | 텍스트가 포함된 뷰 (래스터화로 선명도 저하) |
| 복잡한 커스텀 Shape 조합 | 접근성 요소가 있는 뷰 (VoiceOver 트리 손실) |
| 파티클 이펙트, 시각화 차트 | 인터랙티브 자식 뷰 (탭, 스크롤 등) |
| Canvas와 유사한 드로잉 집약 뷰 | 간단한 레이아웃 (오히려 오버헤드 추가) |

### 코드 예제: 100개 겹치는 Circle

```swift
struct OverlappingCirclesView: View {
    let circleCount = 100
    
    var body: some View {
        VStack(spacing: 40) {
            Text("drawingGroup 비교")
                .font(.headline)
            
            // ❌ drawingGroup 없음: 100개 CALayer 생성
            ZStack {
                ForEach(0..<circleCount, id: \.self) { i in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    .blue.opacity(0.3),
                                    .purple.opacity(0.1)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .offset(
                            x: CGFloat.random(in: -80...80),
                            y: CGFloat.random(in: -80...80)
                        )
                }
            }
            .frame(width: 300, height: 300)
            
            // ✅ drawingGroup 적용: Metal로 오프스크린 래스터라이즈
            ZStack {
                ForEach(0..<circleCount, id: \.self) { i in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    .blue.opacity(0.3),
                                    .purple.opacity(0.1)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .offset(
                            x: CGFloat.random(in: -80...80),
                            y: CGFloat.random(in: -80...80)
                        )
                }
            }
            .frame(width: 300, height: 300)
            .drawingGroup() // Metal 가속 적용
        }
    }
}
```

### 애니메이션 시나리오에서의 효과

`drawingGroup()`의 효과는 **애니메이션이 진행 중**일 때 극적으로 나타납니다. 다음은 100개의 원이 동시에 움직이는 예제입니다.

```swift
struct AnimatedParticles: View {
    @State private var animate = false
    let particleCount = 100
    
    var body: some View {
        ZStack {
            ForEach(0..<particleCount, id: \.self) { i in
                Circle()
                    .fill(.orange.opacity(0.4))
                    .frame(width: 20, height: 20)
                    .offset(
                        x: animate
                            ? CGFloat.random(in: -150...150)
                            : 0,
                        y: animate
                            ? CGFloat.random(in: -150...150)
                            : 0
                    )
                    .animation(
                        .easeInOut(duration: 2)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.02),
                        value: animate
                    )
            }
        }
        .frame(width: 300, height: 300)
        .drawingGroup() // 애니메이션 성능 대폭 향상
        .onAppear { animate = true }
    }
}
```

> **Tip**: Instruments의 **Core Animation** 트랙에서 `drawingGroup()` 적용 전후의 Commit 횟수와 Offscreen Render 횟수를 비교하면 효과를 수치로 확인할 수 있습니다.

---

## 14.7 Swift Concurrency 성능 이슈

🔴 고급

Swift Concurrency는 안전하고 구조화된 비동기 프로그래밍을 제공하지만, 올바르게 사용하지 않으면 의외의 성능 병목이 발생할 수 있습니다.

### Actor 호핑(Hopping) 비용

Actor 간 메시지 전달 시마다 **컨텍스트 스위칭(context switch)**이 발생합니다. 이를 **actor hopping**이라고 합니다. 단일 호출은 미미하지만, 루프 안에서 반복하면 누적 비용이 상당합니다.

```swift
// ❌ 매 반복마다 actor hop 발생
actor DataStore {
    private var items: [String: Data] = [:]
    
    func getItem(_ key: String) -> Data? {
        items[key]
    }
    
    func setItem(_ key: String, _ value: Data) {
        items[key] = value
    }
}

// 호출 측에서 루프로 반복 접근
func processAllKeys(_ keys: [String], store: DataStore) async {
    for key in keys {
        // ⚠️ 매번 actor hop 발생 (수천 회)
        if let data = await store.getItem(key) {
            process(data)
        }
    }
}

// ✅ 배치 메서드로 actor hop 최소화
actor DataStore {
    private var items: [String: Data] = [:]
    
    func getItem(_ key: String) -> Data? {
        items[key]
    }
    
    // 배치 조회: actor hop 1회로 해결
    func getItems(_ keys: [String]) -> [String: Data] {
        var result: [String: Data] = [:]
        for key in keys {
            if let value = items[key] {
                result[key] = value
            }
        }
        return result
    }
}

func processAllKeys(_ keys: [String], store: DataStore) async {
    // ✅ actor hop 1회
    let batch = await store.getItems(keys)
    for (_, data) in batch {
        process(data)
    }
}
```

### MainActor 병목

`@MainActor`로 격리된 코드에서 무거운 작업을 수행하면 UI 스레드가 차단됩니다. 특히 `@Observable` 클래스 전체에 `@MainActor`를 붙이는 패턴에서 주의가 필요합니다.

```swift
// ❌ 무거운 작업이 MainActor에서 실행됨
@MainActor
@Observable
class ImageProcessor {
    var processedImage: UIImage?
    var isProcessing = false
    
    func processImage(_ source: UIImage) async {
        isProcessing = true
        // ⚠️ 이 전체가 MainActor에서 실행됨!
        let filtered = applyHeavyFilter(source)  // CPU 집약 작업
        let resized = resize(filtered)            // CPU 집약 작업
        processedImage = resized
        isProcessing = false
    }
    
    private func applyHeavyFilter(_ image: UIImage) -> UIImage {
        // 수백ms 소요되는 필터 처리...
        // ...
        return image
    }
    
    private func resize(_ image: UIImage) -> UIImage {
        // ...
        return image
    }
}

// ✅ 무거운 작업만 nonisolated로 분리
@MainActor
@Observable
class ImageProcessor {
    var processedImage: UIImage?
    var isProcessing = false
    
    func processImage(_ source: UIImage) async {
        isProcessing = true
        
        // MainActor 밖에서 무거운 작업 수행
        let result = await Self.heavyProcessing(source)
        
        // 결과만 MainActor에서 업데이트
        processedImage = result
        isProcessing = false
    }
    
    // nonisolated + static으로 actor 격리에서 벗어남
    nonisolated private static func heavyProcessing(
        _ source: UIImage
    ) async -> UIImage {
        // 기본 executor에서 실행 (MainActor 아님)
        let filtered = applyHeavyFilter(source)
        let resized = resize(filtered)
        return resized
    }
    
    nonisolated private static func applyHeavyFilter(
        _ image: UIImage
    ) -> UIImage {
        // 수백ms 소요되는 필터 처리...
        return image
    }
    
    nonisolated private static func resize(
        _ image: UIImage
    ) -> UIImage {
        // ...
        return image
    }
}
```

### Task 과다 생성과 TaskGroup 스로틀링

`Task`를 무분별하게 생성하면 스레드 풀이 포화되어 오히려 성능이 저하됩니다. Swift Concurrency는 **cooperative thread pool**을 사용하며, 스레드 수는 CPU 코어 수로 제한됩니다.

```swift
// ❌ 수천 개의 Task를 한꺼번에 생성
func downloadAllImages(_ urls: [URL]) async -> [UIImage] {
    // 1000개 URL에 대해 1000개 Task 생성
    // → 스레드 풀 포화, 메모리 급증
    return await withTaskGroup(of: UIImage?.self) { group in
        for url in urls {
            group.addTask {
                await self.downloadImage(url)
            }
        }
        
        var images: [UIImage] = []
        for await image in group {
            if let image { images.append(image) }
        }
        return images
    }
}

// ✅ 동시 실행 수를 제한하는 스로틀링 패턴
func downloadAllImages(_ urls: [URL]) async -> [UIImage] {
    let maxConcurrency = 4  // 동시 다운로드 수 제한
    
    return await withTaskGroup(of: UIImage?.self) { group in
        var iterator = urls.makeIterator()
        var images: [UIImage] = []
        
        // 초기 배치: maxConcurrency 개만 시작
        for _ in 0..<maxConcurrency {
            guard let url = iterator.next() else { break }
            group.addTask { await self.downloadImage(url) }
        }
        
        // 하나가 끝나면 다음 하나를 추가
        for await image in group {
            if let image { images.append(image) }
            
            if let url = iterator.next() {
                group.addTask { await self.downloadImage(url) }
            }
        }
        
        return images
    }
}
```

### nonisolated 활용으로 불필요한 actor hop 제거

`@MainActor` 클래스에서 상태를 읽거나 쓰지 않는 순수 계산 메서드는 `nonisolated`로 선언하여 불필요한 MainActor hop을 제거합니다.

```swift
@MainActor
@Observable
class SearchViewModel {
    var query = ""
    var results: [SearchResult] = []
    
    func search() async {
        let term = query
        
        // ✅ nonisolated 메서드 호출: MainActor hop 없음
        let processed = Self.normalizeQuery(term)
        
        let fetched = await SearchService.fetch(query: processed)
        
        // ✅ nonisolated 메서드 호출: MainActor hop 없음
        let ranked = Self.rankResults(fetched, for: processed)
        
        results = ranked
    }
    
    // 순수 함수는 nonisolated + static
    nonisolated static func normalizeQuery(_ query: String) -> String {
        query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .folding(
                options: .diacriticInsensitive,
                locale: .current
            )
    }
    
    nonisolated static func rankResults(
        _ results: [SearchResult],
        for query: String
    ) -> [SearchResult] {
        results.sorted { a, b in
            let aScore = Self.relevanceScore(a, query: query)
            let bScore = Self.relevanceScore(b, query: query)
            return aScore > bScore
        }
    }
    
    nonisolated private static func relevanceScore(
        _ result: SearchResult,
        query: String
    ) -> Double {
        var score = 0.0
        if result.title.lowercased().hasPrefix(query) {
            score += 10
        }
        if result.title.lowercased().contains(query) {
            score += 5
        }
        score += Double(result.popularity) / 100.0
        return score
    }
}
```

---

## 14.8 _printChanges()를 안전하게 사용하기

`Self._printChanges()`는 SwiftUI의 body가 왜 재호출되었는지 콘솔에 출력하는 매우 유용한 디버깅 도구입니다. 하지만 이것은 **private API**이므로 프로덕션 빌드에 포함되면 안 됩니다.

### #if DEBUG 가드 패턴

```swift
struct MyView: View {
    @State private var count = 0
    
    var body: some View {
        // ✅ DEBUG 빌드에서만 _printChanges() 호출
        #if DEBUG
        let _ = Self._printChanges()
        #endif
        
        VStack {
            Text("Count: \(count)")
            Button("증가") { count += 1 }
        }
    }
}
```

콘솔 출력 예시:

```text
MyView: @self, @identity, _count changed.
MyView: _count changed.
```

`@self`는 뷰 구조체 자체가 새로 생성되었음을, `@identity`는 SwiftUI가 뷰를 새로운 identity로 인식했음을, `_count`는 해당 `@State` 프로퍼티가 변경되었음을 의미합니다.

### ViewModifier로 재사용 가능한 패턴

```swift
struct DebugPrintChanges: ViewModifier {
    let label: String
    
    func body(content: Content) -> some View {
        #if DEBUG
        let _ = Self._printChanges()
        let _ = print("[\(label)] body 호출됨")
        #endif
        content
    }
}

extension View {
    func debugPrintChanges(_ label: String = "") -> some View {
        #if DEBUG
        modifier(DebugPrintChanges(label: label))
        #else
        self
        #endif
    }
}

// 사용
struct ProductView: View {
    var body: some View {
        ExpensiveSubview()
            .debugPrintChanges("ExpensiveSubview")
    }
}
```

### 대안: os_signpost를 활용한 프로덕션 안전 측정

`_printChanges()`를 사용할 수 없는 프로덕션 환경이나 Instruments 연동이 필요한 경우, `os_signpost`를 활용합니다.

```swift
import os

struct PerformanceSignposts {
    static let poi = OSSignposter(
        subsystem: "com.myapp",
        category: .pointsOfInterest
    )
    
    static let rendering = OSSignposter(
        subsystem: "com.myapp",
        category: "Rendering"
    )
}

struct MeasuredView: View {
    let item: Item
    
    var body: some View {
        // Instruments의 os_signpost 트랙에서 확인 가능
        let signpostID = PerformanceSignposts.rendering
            .makeSignpostID()
        let state = PerformanceSignposts.rendering
            .beginInterval("MeasuredView.body", id: signpostID)
        
        let content = VStack {
            Text(item.title)
            Text(item.subtitle)
                .font(.caption)
        }
        
        let _ = PerformanceSignposts.rendering
            .endInterval("MeasuredView.body", state)
        
        content
    }
}
```

`os_signpost`는 Instruments의 **os_signpost** 트랙에서 시각적으로 확인할 수 있어, body 호출 시간을 그래프로 분석할 수 있습니다. 프로덕션 빌드에서도 안전하게 사용할 수 있으며, Instruments에 연결하지 않으면 런타임 비용이 거의 없습니다.

---

## 정리

- **측정 먼저**: `Self._printChanges()`와 Instruments로 실제 병목을 찾은 후 최적화합니다.

- **body 최적화**: body 안에서 객체 생성, 정렬, 필터링을 피합니다. View를 작게 분리하여 재호출 범위를 줄입니다.

- **Lazy 컨테이너**: 긴 리스트에는 반드시 `LazyVStack`/`LazyHStack`을 사용합니다. List는 이미 lazy하게 동작합니다.

- **이미지 최적화**: 표시 크기에 맞게 다운샘플링하여 메모리를 절약합니다. 비동기 로딩과 캐싱을 조합합니다.

- **Instruments**: SwiftUI 템플릿으로 body 호출 횟수와 시간, Time Profiler로 CPU 병목, Allocations로 메모리 문제를 진단합니다.

이것으로 14개 장의 본문이 완성되었습니다. 다음은 부록입니다.
