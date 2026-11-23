# Interrupted New Game in older builds

Before this retirement, Title inspected a creation journal written by earlier development builds and could resume an interrupted New Game after a restart. The previous implementation is available at `b04979d`. Current New Game starts in memory. Starting the game now leaves unfinished entries on disk and opens Title without attempting to finish them.

SaveManager can still read a completed creation record when a saved scene explicitly references it. Retry during a live transition, checkpoint Load, and Global reading history have separate owners.
