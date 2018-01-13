//
//  ViewController.swift
//  Swiftitle
//
//  Created by Gonzo Fialho on 12/01/18.
//  Copyright © 2018 Gonzo Fialho. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    @IBOutlet weak var destinationView: DestinationView! {
        didSet {
            destinationView.delegate = self
        }
    }

    @IBOutlet weak var label: NSTextField!

    @IBOutlet weak var tableView: NSTableView!
    var isGettingSubtitles = false

    private var moviesToSubtitle = [Movie]() {
        didSet {
            guard !moviesToSubtitle.isEmpty else {
                label.stringValue = "Drag movie files here"
                return
            }

            label.stringValue = "Getting subtitle for \(moviesToSubtitle.first!.name)"
            if moviesToSubtitle.count > 1 {
                label.stringValue += ", \(moviesToSubtitle.count - 1) remaining"
            }
        }
    }

    private var waitingMovies: [Movie] {
        return moviesToSubtitle.filter { $0.state == Movie.State.waiting }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    func getSubtitles() {
        guard let movie = waitingMovies.first else {
            isGettingSubtitles = false
            return
        }

        isGettingSubtitles = true
        movie.state = .downloading
        updateRow(of: movie)
        print("downloading", movie.name)
        do {
            try Subtitler(filePath: movie.url.path, language: "pt").addSubtitleToFile { (error) in
                movie.state = error == nil ? .done : .error
                self.updateRow(of: movie)
                self.getSubtitles()
            }
        } catch {
            movie.state = .error
            updateRow(of: movie)
            getSubtitles()
        }
    }

    func getMovies(in urls: [URL]) -> [Movie] {
        let fm = FileManager.default
        var filteredURLS = [Movie]()

        for url in urls {
            do {
                guard let isDirectory = fm.isDirectory(url) else {
                    continue
                }

                if isDirectory {
                    let directoryList = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                    filteredURLS.append(contentsOf: getMovies(in: directoryList))
                } else if url.UTIConformsTo(kUTTypeMovie) {
                    filteredURLS.append(Movie(url: url))
                }
            } catch {
                print(error)
            }
        }

        return filteredURLS
    }

    func movie(at row: Int) -> Movie {
        return moviesToSubtitle[row]
    }

    func row(of movie: Movie) -> Int? {
        return moviesToSubtitle.index(of: movie)
    }

    func updateRow(of movie: Movie) {
        guard let row = self.row(of: movie) else {
            return
        }

        tableView.reloadData(forRowIndexes: [row], columnIndexes: [1])
    }
}

extension ViewController: NSTableViewDelegate {

}

extension ViewController: NSTableViewDataSource {


    func numberOfRows(in tableView: NSTableView) -> Int {
        return moviesToSubtitle.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let movie = self.movie(at: row)

        switch tableColumn!.title {
        case "Movie": return movie.name
        case "State": return movie.state.rawValue
        default: break
        }

        return nil
    }
}

extension ViewController: DestinationViewDelegate {
    func droppedURLS(_ urls: [URL]) {
        let filteredMovies = getMovies(in: urls)
        if !isGettingSubtitles {
            moviesToSubtitle = filteredMovies
            getSubtitles()
        } else {
            moviesToSubtitle.append(contentsOf: filteredMovies)
        }

        tableView.reloadData()
    }
}
