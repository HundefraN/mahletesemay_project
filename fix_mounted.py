import re
import subprocess

def get_analyzer_output():
    result = subprocess.run(["flutter", "analyze"], capture_output=True, text=True)
    return result.stdout + result.stderr

def fix_all():
    output = get_analyzer_output()
    pattern = re.compile(r"info • Don't use 'BuildContext's across async gaps(?:, guarded by an unrelated 'mounted' check)? • (lib/.*?):(\d+):(\d+) • use_build_context_synchronously")
    matches = pattern.findall(output)
    
    # Process files
    files = {}
    for match in matches:
        path, line, col = match
        line = int(line) - 1
        if path not in files:
            with open(path, "r") as f:
                files[path] = f.readlines()
        
        # We need to insert `if (!context.mounted) return;\n` before this line,
        # OR replace existing `if (!mounted) return;` or `if (mounted)` with `context.mounted`
        
        # First, let's scan backwards up to 15 lines for `await`
        await_line = -1
        for i in range(line, max(-1, line - 15), -1):
            if "await " in files[path][i]:
                await_line = i
                break
        
        if await_line != -1:
            # Let's see if there is already a mounted check between await and usage
            has_mounted = False
            for i in range(await_line + 1, line + 1):
                if "mounted" in files[path][i]:
                    has_mounted = True
                    break
            
            if not has_mounted:
                # Insert it right after await
                indent = len(files[path][await_line+1]) - len(files[path][await_line+1].lstrip())
                insertion = " " * indent + "if (!context.mounted) return;\n"
                # avoid duplicate
                if "if (!context.mounted) return;" not in files[path][await_line+1]:
                    files[path].insert(await_line + 1, insertion)
                    # Shift other line numbers down? We should sort matches descending by line number to avoid this.

    # But we need to sort matches by line descending first
    matches.sort(key=lambda x: (x[0], -int(x[1])))
    
    files = {}
    for match in matches:
        path, line, col = match
        line = int(line) - 1
        if path not in files:
            with open(path, "r") as f:
                files[path] = f.readlines()
                
        # To avoid the unrelated mounted check, let's just globally replace `mounted` with `context.mounted` in the whole file
        # BUT only if it is preceded by non-alphanumeric and not a dot
        for i in range(len(files[path])):
            files[path][i] = re.sub(r'(?<![a-zA-Z0-9_.])mounted\b', 'context.mounted', files[path][i])
            
        # Scan for await and insert
        await_line = -1
        for i in range(line, max(-1, line - 20), -1):
            if "await " in files[path][i]:
                await_line = i
                break
                
        if await_line != -1:
            # check if there's already a check
            has_check = False
            for i in range(await_line + 1, line + 1):
                if "context.mounted" in files[path][i]:
                    has_check = True
                    break
            if not has_check:
                indent = len(files[path][await_line+1]) - len(files[path][await_line+1].lstrip())
                insertion = " " * indent + "if (!context.mounted) return;\n"
                files[path].insert(await_line + 1, insertion)
                
    for path, lines in files.items():
        with open(path, "w") as f:
            f.writelines(lines)
        print(f"Fixed in {path}")

if __name__ == '__main__':
    fix_all()
