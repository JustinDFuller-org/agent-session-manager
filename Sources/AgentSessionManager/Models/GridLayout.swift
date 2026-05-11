import Foundation

struct GridLayout {
    let columns: Int
    let rows: Int
    let paneCount: Int

    var totalCells: Int { columns * rows }
    var emptyCells: Int { totalCells - paneCount }

    static func layout(for count: Int) -> GridLayout {
        let cols: Int
        let rows: Int
        switch count {
        case 0, 1:
            cols = 1
            rows = 1
        case 2:
            cols = 2
            rows = 1
        case 3, 4:
            cols = 2
            rows = 2
        case 5, 6:
            cols = 3
            rows = 2
        default:
            cols = 3
            rows = 3
        }
        return GridLayout(columns: cols, rows: rows, paneCount: count)
    }
}
