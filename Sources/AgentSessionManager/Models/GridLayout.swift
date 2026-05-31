import Foundation

struct GridLayout {
    let columns: Int
    let rows: Int
    let paneCount: Int

    var totalCells: Int { columns * rows }
    var emptyCells: Int { totalCells - paneCount }

}
