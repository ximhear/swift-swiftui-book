// Ch01 - Existential Type과 성능 영향

// MARK: - 프로토콜과 Existential Container

protocol Animal {
    func speak()
}

struct Cat: Animal {
    var name: String
    func speak() { print("야옹") }
}

struct Dog: Animal {
    var name: String
    var breed: String
    func speak() { print("멍멍") }
}

struct Elephant: Animal {
    var name: String
    var weight: Double
    var age: Int
    var habitat: String
    // 24바이트 초과 → 힙 할당 발생

    func speak() { print("뿌우") }
}

// MARK: - 정적 디스패치 vs 동적 디스패치

// 구체 타입 — 정적 디스패치
func feedCat(_ cat: Cat) {
    cat.speak()  // 컴파일러가 직접 Cat.speak() 호출
}

// Existential Type — 동적 디스패치
func feedAnimal(_ animal: any Animal) {
    animal.speak()  // Protocol Witness Table을 통해 간접 호출
}

// some 사용 — 정적 디스패치 유지 (Swift 5.7+)
func feedSomeAnimal(_ animal: some Animal) {
    animal.speak()  // 컴파일 타임에 구체 타입 결정
}
