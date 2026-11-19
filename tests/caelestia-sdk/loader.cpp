#include <QGuiApplication>
#include <QCoreApplication>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QPointer>
#include <QTextStream>
#include "entrypointloader.hpp"
#include "pluginmanifest.hpp"

int main(int argc, char **argv) {
    QGuiApplication app(argc, argv);
    if (argc != 2) return 2;
    QQmlEngine engine;
    QQmlComponent component(&engine, QUrl::fromLocalFile(QString::fromLocal8Bit(argv[1])));
    QScopedPointer<QObject> object(component.create());
    if (!object) {
        QTextStream(stderr) << component.errorString();
        return 1;
    }
    auto *loader = qobject_cast<caelestia::plugins::EntryPointLoader *>(object.get());
    if (!loader || !loader->item()) return 1;
    const auto first = loader->item();
    QPointer<QObject> oldSettings = first->property("settings").value<QObject *>();
    if (!oldSettings || oldSettings->property("schemaVersion").toInt() != 1) return 1;
    oldSettings->setProperty("probeSeconds", 37);
    const auto plugin = loader->entryPoint().plugin();
    if (!plugin || plugin->id() != "syncshell/syncshell") return 1;
    plugin->setGeneration(plugin->generation() + 1);
    if (!loader->item() || loader->item() == first) return 1;
    const auto settings = loader->item()->property("settings").value<QObject *>();
    if (!settings || settings == oldSettings || settings->property("probeSeconds").toInt() != 37) return 1;
    if (loader->item()->property("priorProbe").toInt() != 1) return 1;
    QCoreApplication::sendPostedEvents(nullptr, QEvent::DeferredDelete);
    if (oldSettings) return 1;
    QTextStream(stdout) << "[ok] actual loader settings injection, generation rebinding and stable JS state\n";
    return 0;
}
