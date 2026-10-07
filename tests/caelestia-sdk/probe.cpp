#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QTextStream>
#include "pluginmanifest.hpp"
#include "pluginmodule.hpp"

int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    if (argc != 2) return 2;
    const auto directory = QDir(QString::fromLocal8Bit(argv[1])).absolutePath();
    caelestia::plugins::PluginManifest manifest(directory, directory + "/manifest.json");
    if (!manifest.valid()) {
        QTextStream(stderr) << manifest.error() << '\n';
        return 1;
    }
    caelestia::plugins::PluginModule module(directory, manifest.moduleUri());
    module.scan({});
    for (const auto &warning : module.warnings()) {
        if (!warning.contains("hot reloading is not supported for JavaScript files")
            && !warning.startsWith("syncshell-modern: invalid subdirectory name")) {
            QTextStream(stderr) << warning << '\n';
            return 1;
        }
    }
    bool singleton = false;
    for (const auto &type : module.types()) {
        if (type.name == "CaelestiaService") singleton = type.singleton;
        QTextStream(stdout) << type.uri << ' ' << type.name << '\n';
    }
    if (!singleton) return 1;
    for (const auto &entry : manifest.entryPoints()) {
        if (!QFile::exists(directory + '/' + entry.source())) return 1;
    }
    return 0;
}
