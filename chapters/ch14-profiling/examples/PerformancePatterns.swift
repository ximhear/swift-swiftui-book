// Ch14 - 성능 최적화 패턴

import SwiftUI
import UIKit

// MARK: - body 재호출 모니터링

// 렌더 횟수는 SwiftUI가 추적하지 않는 참조 타입에 보관한다.
final class RenderCounter {
    private var count = 0

    func record(_ label: String) {
        count += 1
        if count > 10 {
            print("[\(label)] \(count)회 렌더링")
        }
    }
}

struct PerformanceMonitor: ViewModifier {
    let label: String
    // @State에는 참조만 담는다. body에서 이 값(참조)을 바꾸지 않는다.
    @State private var counter = RenderCounter()

    func body(content: Content) -> some View {
        // body가 왜 다시 호출됐는지 출력 (상태 변경 없음)
        let _ = Self._printChanges()
        // 참조 타입의 내부 카운터만 증가 — SwiftUI 무효화를 트리거하지 않는다.
        let _ = counter.record(label)
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

// MARK: - DateFormatter 캐시

struct DateView: View {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.locale = Locale(identifier: "ko_KR")
        return f
    }()

    var body: some View {
        Text(Self.formatter.string(from: Date.now))
    }
}

// MARK: - Lazy 컨테이너

struct OptimizedScrollView: View {
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(0..<10000, id: \.self) { i in
                    Text("항목 \(i)")
                        .frame(height: 44)
                }
            }
        }
    }
}

// MARK: - 이미지 다운샘플링

extension UIImage {
    static func downsample(
        at url: URL,
        to pointSize: CGSize,
        scale: CGFloat = UITraitCollection.current.displayScale
    ) -> UIImage? {
        let options = [
            kCGImageSourceShouldCache: false
        ] as CFDictionary

        guard let source = CGImageSourceCreateWithURL(
            url as CFURL, options) else { return nil }

        let maxDim = max(
            pointSize.width, pointSize.height) * scale
        let thumbOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDim
        ] as CFDictionary

        guard let cgImage =
            CGImageSourceCreateThumbnailAtIndex(
                source, 0, thumbOptions)
        else { return nil }

        return UIImage(cgImage: cgImage)
    }
}

// MARK: - 비동기 썸네일

struct ThumbnailView: View {
    let url: URL
    let size: CGSize
    // 메인 스레드에서 환경값으로 displayScale을 받는다.
    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle().fill(.gray.opacity(0.2))
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: url) {
            // displayScale을 메인에서 캡처한 뒤 백그라운드로 전달
            let scale = displayScale
            image = await Task.detached(
                priority: .utility) {
                UIImage.downsample(at: url, to: size, scale: scale)
            }.value
        }
    }
}
