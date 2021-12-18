import Cocoa

class KeyboardInputWindow: TransparentWindow {

    override func awakeFromNib() {
        super.awakeFromNib()

        backgroundColor = .clear
        delegate = self

        makeFirstResponder(self)
    }

    var appDelegate: AppDelegate? {
        NSApp.delegate as? AppDelegate
    }

    let mouse = Mouse()

    // The underlying data structure enabling cursor movement via a
    // character-based decision tree.
    var tree: Tree<CGRect>! {
        didSet {
            currentNode = nil
        }
    }

    // Non-nil, if the user is in the process of entering a key sequence to
    // navigate via the decision tree.
    var currentNode: Tree<CGRect>.Node<CGRect>? {
        didSet {
            if let currentNode = currentNode {
                currentSequence.append(currentNode.label)
            } else {
                currentSequence = []
            }
            redrawGridViews()
        }
    }

    // The sequence of characters that the user has entered, when navigating
    // via the decision tree.
    var currentSequence = [Character]()

    var isWalkingDecisionTree: Bool {
        currentNode != nil
    }

    var isHoldingDownMouseButton = false

    static let DEFAULT_CELL_SIZE = CGSize(width: 60.0, height: 60.0)

    var targetCellSize = DEFAULT_CELL_SIZE {
        didSet {
            targetCellSize = clamp(
                targetCellSize,
                minValue: CGSize(width: 45.0, height: 45.0),
                maxValue: CGSize(width: 90.0, height: 90.0)
            )
            if targetCellSize != oldValue {
                initializeCoreDataStructures()
            }
        }
    }

    let numStepsPerCell = CGFloat(6.0)

    /// The screen that the mouse cursor is currently on.
    var activeScreen: NSScreen? {
        mouse.currentScreen
    }

    /// The grid corresponding to the screen that the mouse cursor is currently on.
    var activeGrid: Grid? {
        guard let activeScreen = activeScreen else {
            return nil
        }

        return appDelegate?.jumpWindowController(for: activeScreen)?.viewController.grid
    }

    var stepWidth: CGFloat {
        (activeGrid?.cellWidth ?? targetCellSize.width) / numStepsPerCell
    }

    var stepHeight: CGFloat {
        (activeGrid?.cellHeight ?? targetCellSize.height) / numStepsPerCell
    }

    func initializeCoreDataStructures() {

        guard let jumpWindowControllers = appDelegate?.jumpWindowControllers else {
            return
        }

        var data = [(grid: Grid, screenRects: [CGRect])]()

        for jumpWindowController in jumpWindowControllers {
            guard let screen = jumpWindowController.assignedScreen else {
                return
            }

            let grid = Grid(gridSize: screen.visibleFrame.size,
                            targetCellSize: targetCellSize)

            jumpWindowController.viewController.grid = grid

            // All rects, transformed into screen coordinates. (This
            // transformation is needed to account for cases where multiple
            // screens are connected.)
            let screenRects = grid.rects.map {
                CGRect(
                    x: $0.origin.x + screen.frame.origin.x,
                    y: $0.origin.y + screen.frame.origin.y,
                    width: $0.width,
                    height: $0.height
                )
            }

            data.append((grid, screenRects))
        }

        let candidates = data.flatMap { $0.screenRects }

        let tree = Tree(
            candidates: candidates,
            keys: determineAvailableKeys(numCandidates: candidates.count)
        )

        for (n, (grid, _)) in data.enumerated() {
            assert(grid.numCells == grid.rects.count)

            let startIndex = data[0..<n].reduce(0, { $0 + $1.grid.numCells })
            let endIndex = startIndex + grid.numCells

            let sequences = tree.sequences[startIndex..<endIndex]

            grid.data = Array(sequences)
        }

        assert(tree.sequences.count == candidates.count)

        self.tree = tree
    }

    func determineAvailableKeys(numCandidates: Int) -> [Character] {

        let keys: [[Character]] = [
            ["a", "s", "d", "f", "j", "k", "l"],
            ["g", "h"],
            ["q", "w", "e", "r", "u", "i", "o", "p"],
            ["t", "y"],
            ["z", "x", "c", "v", "b", "n", "m"],
            [";"],
        ]

        switch numCandidates {
        case 0..<800:
            return keys[0] + keys[1]
        case 800..<1200:
            return keys[0] + keys[1] + keys[2]
        case 1200..<1400:
            return keys[0] + keys[1] + keys[2] + keys[3]
        default:
            return keys.flatMap { $0 }
        }
    }

}
