//
//  URL+AcquireAccessFromSandbox.swift
//  DevCleaner
//
//  Created by Konrad Kołakowski on 16.09.2018.
//  Copyright © 2018 One Minute Games. All rights reserved.
//

import Foundation
import Cocoa

extension URL {
    private struct SandboxFolderAccessError: Error {
        
    }
    
    public func acquireAccessFromSandbox(bookmark: Data? = nil, openPanelMessage: String = "Application needs permission to access this folder") -> URL? {
        func doWeHaveAccess(for path: String) -> Bool {
            let fm = FileManager.default
            
            return fm.isReadableFile(atPath: path) && fm.isWritableFile(atPath: path)
        }
        
        // check if we already have access, then we don't need to show the dialog or use security bookmarks
        if doWeHaveAccess(for: self.path) {
            return self
        }
        
        // if we don't have access, so first try to load security bookmark
        if let bookmarkData = bookmark {
            do {
                var isBookmarkStale = false
                let bookmarkedUrl = try URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isBookmarkStale)
                
                if !isBookmarkStale {
                    if doWeHaveAccess(for: bookmarkedUrl.path) {
                        return bookmarkedUrl
                    } else {
                        throw SandboxFolderAccessError()
                    }
                } else {
                    throw SandboxFolderAccessError()
                }
            } catch { // in case of stale bookmark or fail to get one, try again without it
                return self.acquireAccessFromSandbox(bookmark: nil, openPanelMessage: openPanelMessage)
            }
        }
        
        // well, so maybe first acquire the bookmark by opening open panel?
        let openPanel = NSOpenPanel()
        openPanel.directoryURL = self
        openPanel.message = openPanelMessage
        openPanel.prompt = "Open"
        
        openPanel.allowedFileTypes = ["none"]
        openPanel.allowsOtherFileTypes = false
        openPanel.canChooseDirectories = true
        
        openPanel.runModal()
        
        // check if we get proper file & save bookmark to it, if not, repeat
        if let folderUrl = openPanel.urls.first {
            if folderUrl != self {
                Alerts.infoAlert(title: "Can't get access to \(self.path) folder",
                               message: "Did you choose the right folder?",
                          okButtonText: "Repeat")
                
                return self.acquireAccessFromSandbox(bookmark: nil, openPanelMessage: openPanelMessage)
            }
            
            if doWeHaveAccess(for: folderUrl.path) {
                if let bookmarkData = try? folderUrl.bookmarkData() {
                    Preferences.shared.setFolderBookmark(bookmarkData: bookmarkData, for: self)
                    
                    return folderUrl
                }
            } else {
                // well, we tried but we can't get access to this folder
                
                // delete folder bookmark just in case
                Preferences.shared.setFolderBookmark(bookmarkData: nil, for: self)
                
                return nil
            }
        }
        
        return self.acquireAccessFromSandbox(bookmark: nil, openPanelMessage: openPanelMessage)
    }
}
