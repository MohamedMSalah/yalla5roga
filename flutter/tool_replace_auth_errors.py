from pathlib import Path
import re

path = Path(r"lib/features/auth/presentation/providers/auth_provider.dart")
text = path.read_text(encoding="utf-8")
pattern = re.compile(
    r"AppErrorFeedback\.report\(\s*"
    r"(failure|const AuthFailure\([^)]*\)),\s*"
    r"kind: AppErrorKind\.send,\s*"
    r"context: ('[^']+'),\s*"
    r"\)",
    re.M,
)
text2, n = pattern.subn(r"_reportFailure(\1, context: \2)", text)
print("replacements", n)
path.write_text(text2, encoding="utf-8")
