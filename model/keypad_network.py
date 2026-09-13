"""Graph model of a 4x4 keypad with open-drain row scanning."""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum


class ScanKind(Enum):
    NONE = "NONE"
    ONE = "ONE"
    MULTI = "MULTI"


@dataclass(frozen=True)
class ScanResult:
    kind: ScanKind
    key_id: int | None = None


def _validate_mask(mask: int) -> None:
    if not 0 <= mask < (1 << 16):
        raise ValueError("key mask must contain exactly 16 bits")


def low_columns(mask: int, driven_row: int) -> int:
    """Return active-low column observations as a 4-bit hit mask.

    Rows are nodes 0..3, columns are nodes 4..7. Every pressed key is an
    undirected edge. A column reads low exactly when its connected component
    contains the currently driven-low row.
    """
    _validate_mask(mask)
    if not 0 <= driven_row < 4:
        raise ValueError("driven_row must be in range 0..3")
    adjacency = [set() for _ in range(8)]
    for row in range(4):
        for column in range(4):
            if mask & (1 << (4 * row + column)):
                row_node = row
                column_node = 4 + column
                adjacency[row_node].add(column_node)
                adjacency[column_node].add(row_node)
    reached = {driven_row}
    work = [driven_row]
    while work:
        node = work.pop()
        for neighbour in adjacency[node] - reached:
            reached.add(neighbour)
            work.append(neighbour)
    result = 0
    for column in range(4):
        if 4 + column in reached:
            result |= 1 << column
    return result


def scan_matrix(mask: int) -> tuple[int, int, int, int]:
    return tuple(low_columns(mask, row) for row in range(4))  # type: ignore[return-value]


def classify_scan(mask: int) -> ScanResult:
    """Classify all observed row/column hits, saturating at MULTI."""
    first: int | None = None
    hits = 0
    for row, columns in enumerate(scan_matrix(mask)):
        for column in range(4):
            if columns & (1 << column):
                hits += 1
                if first is None:
                    first = 4 * row + column
                if hits >= 2:
                    return ScanResult(ScanKind.MULTI)
    if hits == 0:
        return ScanResult(ScanKind.NONE)
    return ScanResult(ScanKind.ONE, first)

