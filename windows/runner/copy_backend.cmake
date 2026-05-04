# copy_backend.cmake
# Called by add_custom_command POST_BUILD in runner/CMakeLists.txt
# Variables passed in: SRC, DST

if(NOT EXISTS "${SRC}")
  message(WARNING "[Cyborg] Backend source not found: ${SRC}")
  return()
endif()

# Remove stale backend (but preserve .venv if it exists — don't wipe the user's env)
set(VENV_BACKUP "${DST}/.venv_backup_tmp")
if(EXISTS "${DST}/.venv")
  message(STATUS "[Cyborg] Preserving existing .venv during backend sync...")
  file(RENAME "${DST}/.venv" "${VENV_BACKUP}")
endif()

file(REMOVE_RECURSE "${DST}")
file(MAKE_DIRECTORY "${DST}")

# Restore .venv if it was backed up
if(EXISTS "${VENV_BACKUP}")
  file(RENAME "${VENV_BACKUP}" "${DST}/.venv")
endif()

# Copy backend source files (exclude runtime-generated dirs)
file(GLOB_RECURSE BACKEND_FILES
  LIST_DIRECTORIES false
  "${SRC}/*"
)

foreach(FILE_PATH ${BACKEND_FILES})
  # Skip excluded directories
  if(FILE_PATH MATCHES "/__pycache__/" OR
     FILE_PATH MATCHES "/\\.venv/" OR
     FILE_PATH MATCHES "/logs/" OR
     FILE_PATH MATCHES "/cache/" OR
     FILE_PATH MATCHES "/checkpoints/" OR
     FILE_PATH MATCHES "\\.pyc$")
    continue()
  endif()

  # Compute relative path and destination
  file(RELATIVE_PATH REL_PATH "${SRC}" "${FILE_PATH}")
  get_filename_component(DEST_DIR "${DST}/${REL_PATH}" DIRECTORY)
  file(MAKE_DIRECTORY "${DEST_DIR}")
  file(COPY_FILE "${FILE_PATH}" "${DST}/${REL_PATH}" ONLY_IF_DIFFERENT)
endforeach()

message(STATUS "[Cyborg] Backend synced to: ${DST}")
