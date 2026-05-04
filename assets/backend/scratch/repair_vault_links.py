
import asyncio
import sys
import os
from pathlib import Path

# Add backend to path
BACKEND_DIR = Path(__file__).parent.parent.absolute()
sys.path.append(str(BACKEND_DIR))
os.chdir(BACKEND_DIR) # Change to backend dir for relative settings to work

from services.vault_service import VaultService
from config.settings import settings

async def repair_links():
    print("Initializing Vault Service...")
    vault = VaultService()
    await vault.initialize()
    
    all_notes = list(vault._notes_cache.values())
    print(f"Found {len(all_notes)} notes in vault.")
    
    created_count = 0
    
    # 1. Collect all missing targets
    missing_targets = set()
    title_to_id = {n.title.lower(): n.id for n in all_notes}
    
    for note in all_notes:
        for link in note.links:
            if link.lower() not in title_to_id:
                missing_targets.add(link)
    
    print(f"Found {len(missing_targets)} missing link targets.")
    
    # 2. Create stub notes for missing targets
    for target in missing_targets:
        try:
            print(f"Creating stub note for: {target}")
        except UnicodeEncodeError:
            print(f"Creating stub note for: [unicode_label]")
        
        await vault.create_note(
            title=target,
            content=f"# {target}\n\nAuto-generated concept node for graph connectivity.",
            folder="atlas",
            tags=["concept", "auto-generated"]
        )
        created_count += 1
        # Update local title_to_id to avoid duplicates in same run
        title_to_id[target.lower()] = "new"

    print(f"Repair complete. Created {created_count} new concept notes.")

if __name__ == "__main__":
    asyncio.run(repair_links())
