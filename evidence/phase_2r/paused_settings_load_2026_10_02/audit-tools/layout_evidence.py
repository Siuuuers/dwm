"""Scope the shared audited cloud packager to this title-geometry investigation.

Every extracted member is still verified against the original artifact ZIP.
Only the two relevant title images are embedded; all other image identities and
their original artifact provenance remain in the exclusion manifest.
"""
import cloud_evidence as cloud

original_exclusion = cloud.exclusion

def layout_exclusion(path, artifact):
    reason = original_exclusion(path, artifact)
    if reason is not None:
        return reason
    if path.suffix.lower() == '.png' and path.name not in (
        '02-next-board.png', '03-next-restored-board.png'
    ):
        return ('Outside the selected title-geometry visual scope. Original ZIP member bytes, '
                'size and SHA-256 verified; identity retained here. Semantic reports remain embedded.')
    return None

cloud.exclusion = layout_exclusion

if __name__ == '__main__':
    cloud.main()
