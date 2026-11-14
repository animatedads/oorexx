/* oodqt.cpp -- the Qt6 renderer behind ooDialog's oodWeb.cls, on Linux.
 *
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 2026-11-14.
 *
 * Upstream ooDialog's Rexx classes run unchanged; oodWeb.cls (Claude
 * (Fable 5.2)) answers their native entry points and reaches a renderer
 * through one object with 15 messages.  In the browser that object is the
 * page runtime oodialog-web.js; here it is this library, reached from
 * Rexx through two routines of the ooRexx native API:
 *
 *   oodqt_call(name, payload) -> string   one renderer message
 *   oodqt_next(ms)            -> string   run Qt up to ms; one queued event or ""
 *
 * Fields are separated by 0x1F, records by 0x1E.  Events are
 * "key 1F kind 1F id 1F code 1F extra", the arguments oodWeb's pageEvent
 * takes.  Rexx is only ever called back through oodqt_next's return value,
 * so nothing re-enters the interpreter from a Qt signal.
 *
 * Behaviour follows oodialog-web.js where it defines it (dialog units,
 * subscriptions, ops, Win32 messages).  The steps player
 * (OODQT_STEPS=file) drives the same .steps files as the browser harness.
 */
#include <oorexxapi.h>

#include <QApplication>
#include <QButtonGroup>
#include <QCheckBox>
#include <QComboBox>
#include <QDialog>
#include <QDir>
#include <QElapsedTimer>
#include <QEventLoop>
#include <QFile>
#include <QFontMetrics>
#include <QFrame>
#include <QGroupBox>
#include <QKeyEvent>
#include <QLabel>
#include <QLineEdit>
#include <QListWidget>
#include <QMenu>
#include <QMenuBar>
#include <QMessageBox>
#include <QMouseEvent>
#include <QPlainTextEdit>
#include <QProgressBar>
#include <QPushButton>
#include <QRadioButton>
#include <QRegularExpressionValidator>
#include <QScreen>
#include <QTextStream>
#include <QTimer>
#include <QVBoxLayout>

#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <deque>
#include <map>
#include <memory>
#include <set>
#include <vector>

namespace {

const QChar FS(0x1F);
const QChar RS(0x1E);

struct Ctl {
    int id = 0;
    QString kind, opts, rawText;
    QWidget *el = nullptr;     // the placed widget
    QWidget *main = nullptr;   // the widget that takes input
    bool modified = false;
    int group = 0;
};

class OodDialog;

struct Dlg {
    int key = 0;
    QString opts;
    OodDialog *win = nullptr;
    QWidget *client = nullptr;
    QMenuBar *menuBar = nullptr;
    std::map<int, Ctl> ctrls;
    std::vector<int> order;
    std::set<QString> subs;
    std::map<int, QButtonGroup *> radioGroups;
    double fx = 1, fy = 1;
    int defId = 1, group = 0;
    bool shown = false, noClose = false;
};

std::map<int, Dlg *> dialogs;
std::deque<QString> events;
QEventLoop *waiting = nullptr;
QApplication *app = nullptr;
QFile logFile;

bool has(const QString &opts, const char *word) { return opts.contains(QLatin1String(word), Qt::CaseInsensitive); }

QString plain(const QString &text) {             // "&Name" -> "Name", "&&" -> "&"
    QString out;
    for (int i = 0; i < text.size(); ++i) {
        if (text[i] == '&' && i + 1 < text.size()) { out += text[++i]; continue; }
        out += text[i];
    }
    return out;
}

void fire(int key, const QString &kind, const QString &id, const QString &code, const QString &extra = QString()) {
    events.push_back(QString::number(key) + FS + kind + FS + id + FS + code + FS + extra);
    if (waiting) waiting->quit();
}

void cmd(Dlg *d, const Ctl &c, int code, bool always = false) {
    const QString id = QString::number(c.id), cs = QString::number(code);
    if (always || d->subs.count(id + "." + cs) || d->subs.count(id + ".*") || d->subs.count("*." + cs))
        fire(d->key, "CMD", id, cs);
}

QFont dialogFont(const QString &name, double size) {
    QFont f = QApplication::font();
    if (!name.isEmpty() && !name.startsWith("MS Shell Dlg", Qt::CaseInsensitive)
        && !name.startsWith("MS Sans Serif", Qt::CaseInsensitive) && name.compare("System", Qt::CaseInsensitive) != 0)
        f.setFamily(name);
    f.setPixelSize(std::max(1, (int)std::lround(size * 96.0 / 72.0)));
    return f;
}

/* Dialog base units, as Windows computes them from the dialog font (and as oodialog-web.js does). */
void baseUnits(const QFont &f, double &fx, double &fy) {
    QFontMetrics m(f);
    const double w = m.horizontalAdvance(QStringLiteral("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"));
    fx = std::floor((w / 26.0 + 1) / 2) / 4;
    fy = std::round((double)m.height()) / 8;
}

class OodDialog : public QDialog {
public:
    Dlg *d;
    explicit OodDialog(Dlg *dlg, QWidget *parent = nullptr) : QDialog(parent), d(dlg) {}
protected:
    void closeEvent(QCloseEvent *e) override {     // the close box is IDCANCEL; the Rexx side decides
        e->ignore();
        if (!d->noClose) fire(d->key, "CMD", "2", "0");
    }
    void keyPressEvent(QKeyEvent *e) override {
        if (d->subs.count("0.KEY")) {
            QString mods = QString(e->modifiers() & Qt::ShiftModifier ? "S" : "") + (e->modifiers() & Qt::ControlModifier ? "C" : "")
                           + (e->modifiers() & Qt::AltModifier ? "A" : "");
            fire(d->key, "KEY", QString::number(e->nativeVirtualKey() ? e->nativeVirtualKey() : e->key()), mods);
        }
        if (e->key() == Qt::Key_Escape) { if (!d->noClose) fire(d->key, "CMD", "2", "0"); return; }
        if (e->key() == Qt::Key_F1) { fire(d->key, "CMD", "9", "0"); return; }
        if (e->key() == Qt::Key_Return || e->key() == Qt::Key_Enter) {
            QWidget *f = focusWidget();
            if (qobject_cast<QPlainTextEdit *>(f)) return;
            if (auto *b = qobject_cast<QPushButton *>(f)) { b->click(); return; }
            auto it = d->ctrls.find(d->defId);
            if (it != d->ctrls.end() && it->second.kind == "BUTTON") {
                if (it->second.main->isEnabled()) static_cast<QPushButton *>(it->second.main)->click();
            } else fire(d->key, "CMD", "1", "0");
            return;
        }
        QDialog::keyPressEvent(e);
    }
};

/* A static that reports clicks when it has the NOTIFY style. */
class ClickFilter : public QObject {
public:
    Dlg *d; int id;
    ClickFilter(Dlg *dlg, int cid, QObject *p) : QObject(p), d(dlg), id(cid) {}
    bool eventFilter(QObject *, QEvent *e) override {
        if (e->type() == QEvent::MouseButtonRelease) fire(d->key, "CMD", QString::number(id), "0");
        if (e->type() == QEvent::MouseButtonDblClick) fire(d->key, "CMD", QString::number(id), "1");
        return false;
    }
};

std::map<QString, QString> fields(const QString &record) {   // "k=v 1F k=v ..."
    std::map<QString, QString> out;
    for (const QString &f : record.split(FS)) {
        const int eq = f.indexOf('=');
        if (eq > 0) out[f.left(eq)] = f.mid(eq + 1);
    }
    return out;
}

void place(Dlg *d, QWidget *w, double x, double y, double cx, double cy) {
    w->setGeometry((int)std::lround(x * d->fx), (int)std::lround(y * d->fy), (int)std::lround(cx * d->fx), (int)std::lround(cy * d->fy));
}

void addControl(Dlg *d, const std::map<QString, QString> &s) {
    auto get = [&](const char *k) { auto it = s.find(k); return it == s.end() ? QString() : it->second; };
    Ctl c;
    c.id = get("id").toInt();
    c.kind = get("kind").toUpper();
    c.opts = get("opts").toUpper();
    const QString text = get("text");
    c.rawText = text;
    if (has(c.opts, "GROUP")) d->group++;
    c.group = d->group;
    QWidget *parent = d->client;
    const int id = c.id;
    if (c.kind == "BUTTON") {
        auto *b = new QPushButton(text, parent);
        b->setAutoDefault(false);
        if (has(c.opts, "DEFAULT")) { b->setDefault(true); d->defId = id; }
        QObject::connect(b, &QPushButton::clicked, [d, id] { cmd(d, d->ctrls[id], 0, true); });
        c.el = c.main = b;
    } else if (c.kind == "CHECK" || c.kind == "RADIO") {
        QAbstractButton *b;
        if (c.kind == "RADIO") {
            b = new QRadioButton(text, parent);
            b->setAutoExclusive(false);
            auto &g = d->radioGroups[c.group];
            if (!g) { g = new QButtonGroup(d->client); g->setExclusive(true); }
            g->addButton(b);
        } else {
            auto *cb = new QCheckBox(text, parent);
            if (has(c.opts, "3STATE")) cb->setTristate(true);
            b = cb;
        }
        if (has(c.opts, "LTEXT")) b->setLayoutDirection(Qt::RightToLeft);
        QObject::connect(b, &QAbstractButton::clicked, [d, id] { cmd(d, d->ctrls[id], 0, true); });
        c.el = c.main = b;
    } else if (c.kind == "GROUP") {
        auto *g = new QGroupBox(plain(text), parent);
        c.el = c.main = g;
    } else if (c.kind == "STATIC") {
        auto *l = new QLabel(plain(text), parent);
        l->setWordWrap(true);
        Qt::Alignment a = Qt::AlignLeft;
        if (has(c.opts, "CENTER")) a = Qt::AlignHCenter; else if (has(c.opts, "RIGHT")) a = Qt::AlignRight;
        l->setAlignment(a | Qt::AlignTop);
        if (has(c.opts, "BORDER")) l->setFrameStyle(QFrame::Box | QFrame::Plain);
        if (has(c.opts, "NOTIFY")) l->installEventFilter(new ClickFilter(d, id, l));
        c.el = c.main = l;
    } else if (c.kind == "FRAME") {
        auto *f = new QFrame(parent);
        f->setFrameStyle((has(c.opts, "RECT") ? QFrame::Panel : QFrame::Box) | (has(c.opts, "ETCHED") ? QFrame::Sunken : QFrame::Plain));
        if (has(c.opts, "RECT")) {
            f->setAutoFillBackground(true);
            QPalette p = f->palette();
            p.setColor(QPalette::Window, has(c.opts, "WHITE") ? Qt::white : has(c.opts, "GRAY") ? QColor(160, 160, 160) : Qt::black);
            f->setPalette(p);
        }
        c.el = c.main = f;
    } else if (c.kind == "EDIT") {
        if (has(c.opts, "MULTILINE")) {
            auto *t = new QPlainTextEdit(text, parent);
            t->setReadOnly(has(c.opts, "READONLY"));
            QObject::connect(t, &QPlainTextEdit::textChanged, [d, id] { cmd(d, d->ctrls[id], 0x400); cmd(d, d->ctrls[id], 0x300); });
            c.el = c.main = t;
        } else {
            auto *e = new QLineEdit(text, parent);
            if (has(c.opts, "PASSWORD")) e->setEchoMode(QLineEdit::Password);
            e->setReadOnly(has(c.opts, "READONLY"));
            if (has(c.opts, "NUMBER")) e->setValidator(new QRegularExpressionValidator(QRegularExpression("[0-9]*"), e));
            if (has(c.opts, "CENTER")) e->setAlignment(Qt::AlignHCenter); else if (has(c.opts, "RIGHT")) e->setAlignment(Qt::AlignRight);
            if (has(c.opts, "NOBORDER")) e->setFrame(false);
            const bool up = has(c.opts, "UPPER"), low = has(c.opts, "LOWER");
            QObject::connect(e, &QLineEdit::textEdited, [d, id, e, up, low](const QString &t) {
                if (up && t != t.toUpper()) e->setText(t.toUpper());
                if (low && t != t.toLower()) e->setText(t.toLower());
                d->ctrls[id].modified = true;
            });
            QObject::connect(e, &QLineEdit::textChanged, [d, id] { cmd(d, d->ctrls[id], 0x400); cmd(d, d->ctrls[id], 0x300); });
            QObject::connect(e, &QLineEdit::editingFinished, [d, id] { cmd(d, d->ctrls[id], 0x200); });
            c.el = c.main = e;
        }
    } else if (c.kind == "LIST") {
        auto *l = new QListWidget(parent);
        if (has(c.opts, "MULTI")) l->setSelectionMode(has(c.opts, "EXTSEL") ? QAbstractItemView::ExtendedSelection : QAbstractItemView::MultiSelection);
        if (has(c.opts, "SORT")) l->setSortingEnabled(true);
        QObject::connect(l, &QListWidget::currentRowChanged, [d, id] { cmd(d, d->ctrls[id], 1); });
        QObject::connect(l, &QListWidget::itemDoubleClicked, [d, id] { cmd(d, d->ctrls[id], 2); });
        c.el = c.main = l;
    } else if (c.kind == "COMBO") {
        auto *b = new QComboBox(parent);
        const bool droplist = has(c.opts, "LIST") && !has(c.opts, "SIMPLE");
        b->setEditable(!droplist);
        if (has(c.opts, "SORT")) b->setInsertPolicy(QComboBox::InsertAlphabetically);
        QObject::connect(b, QOverload<int>::of(&QComboBox::activated), [d, id] { cmd(d, d->ctrls[id], 9); cmd(d, d->ctrls[id], 1); });
        if (!droplist) QObject::connect(b, &QComboBox::editTextChanged, [d, id] { cmd(d, d->ctrls[id], 6); cmd(d, d->ctrls[id], 5); });
        c.el = c.main = b;
    } else if (c.kind == "PROGRESS") {
        auto *p = new QProgressBar(parent);
        p->setRange(0, 100);
        p->setTextVisible(false);
        if (has(c.opts, "VERTICAL")) p->setOrientation(Qt::Vertical);
        c.el = c.main = p;
    } else {                                              // not yet: shown as a labelled placeholder, as the page does
        auto *l = new QLabel(c.kind + " (not yet)", parent);
        l->setObjectName("ood-todo");
        l->setFrameStyle(QFrame::Box | QFrame::Plain);
        c.el = c.main = l;
    }
    place(d, c.el, get("x").toDouble(), get("y").toDouble(), get("cx").toDouble(), get("cy").toDouble());
    if (has(c.opts, "HIDDEN")) c.el->hide(); else c.el->show();
    if (has(c.opts, "DISABLED")) c.main->setEnabled(false);
    if (has(c.opts, "NOTAB")) c.main->setFocusPolicy(Qt::ClickFocus);
    if (c.kind == "STATIC" || c.kind == "GROUP" || c.kind == "FRAME") c.main->setFocusPolicy(Qt::NoFocus);
    d->ctrls[id] = c;
    d->order.push_back(id);
}

Dlg *dialog(const QString &key) {
    auto it = dialogs.find(key.toInt());
    return it == dialogs.end() ? nullptr : it->second;
}

/*---- menus: records "depth 1F id 1F text 1F flags", joined by 1E ----*/
void buildMenu(Dlg *d, QMenuBar *bar, const QString &data) {
    std::vector<QMenu *> path;
    std::vector<QStringList> recs;
    for (const QString &r : data.split(RS, Qt::SkipEmptyParts)) recs.push_back(r.split(FS));
    for (size_t i = 0; i < recs.size(); ++i) {
        const QStringList &r = recs[i];
        if (r.size() < 3) continue;
        const int depth = r[0].toInt(), id = r[1].toInt();
        const QString text = r[2], flags = " " + (r.size() > 3 ? r[3] : QString()) + " ";
        const bool popup = i + 1 < recs.size() && recs[i + 1][0].toInt() > depth;
        path.resize(depth);
        QWidget *owner = depth == 0 ? (QWidget *)bar : (QWidget *)path[depth - 1];
        if (!owner) continue;
        if (flags.contains(" SEPARATOR ")) {
            if (depth > 0) path[depth - 1]->addSeparator();
            continue;
        }
        if (popup) {
            QMenu *m = depth == 0 ? bar->addMenu(text) : path[depth - 1]->addMenu(text);
            path.push_back(m);
            continue;
        }
        QAction *a = depth == 0 ? bar->addAction(text) : path[depth - 1]->addAction(text);
        a->setEnabled(!flags.contains(" GRAYED ") && !flags.contains(" DISABLED "));
        if (flags.contains(" CHECKED ")) { a->setCheckable(true); a->setChecked(true); }
        const int key = d->key;
        QObject::connect(a, &QAction::triggered, [key, id] { fire(key, "CMD", QString::number(id), "0"); });
    }
}

/*---- the renderer messages ----*/
QString call(const QString &name, const QString &payload) {
    const QStringList a = payload.split(FS);
    auto arg = [&](int i) { return i < a.size() ? a[i] : QString(); };

    if (name == "create") {                              // payload: spec record 1E control records ...
        const QStringList recs = payload.split(RS);
        auto spec = fields(recs.value(0));
        auto *d = new Dlg;
        d->key = spec["key"].toInt();
        d->opts = spec["opts"].toUpper();
        QWidget *host = nullptr;
        if (!spec["parent"].isEmpty()) if (Dlg *h = dialog(spec["parent"])) host = h->client;
        d->win = new OodDialog(d, nullptr);
        d->win->setObjectName("ood-dlg");
        d->win->setWindowTitle(spec["title"]);
        if (has(d->opts, "NOMENU")) d->win->setWindowFlag(Qt::WindowCloseButtonHint, false);
        auto *layout = new QVBoxLayout(d->win);
        layout->setContentsMargins(0, 0, 0, 0);
        layout->setSpacing(0);
        d->client = new QWidget(d->win);
        layout->addWidget(d->client);
        const QFont f = dialogFont(spec["fontName"], spec["fontSize"].isEmpty() ? 8 : spec["fontSize"].toDouble());
        d->win->setFont(f);
        baseUnits(f, d->fx, d->fy);
        const int w = (int)std::lround(spec["cx"].toDouble() * d->fx), h = (int)std::lround(spec["cy"].toDouble() * d->fy);
        d->client->setFixedSize(w, h);
        if (host) { d->win->setParent(host); d->win->setWindowFlags(Qt::Widget); d->win->move(spec["px"].toInt(), spec["py"].toInt()); }
        else if (has(d->opts, "CENTER")) {
            const QRect s = QGuiApplication::primaryScreen()->availableGeometry();
            d->win->move(s.center() - QPoint(w / 2, h / 2));
        } else d->win->move((int)std::lround(spec["x"].toDouble() * d->fx), (int)std::lround(spec["y"].toDouble() * d->fy));
        dialogs[d->key] = d;
        for (int i = 1; i < recs.size(); ++i) addControl(d, fields(recs[i]));
        return QString::number(d->fx) + " " + QString::number(d->fy) + " " + QString::number(w) + " " + QString::number(h);
    }
    if (name == "addControl") {
        Dlg *d = dialog(arg(0)); if (!d) return "0";
        addControl(d, fields(payload.section(RS, 1)));
        return "1";
    }
    if (name == "show") {
        Dlg *d = dialog(arg(0)); if (!d) return "0";
        if (has(arg(1), "HIDE")) { d->win->hide(); return "1"; }
        d->win->show();
        d->win->raise();
        d->win->activateWindow();
        if (!d->shown) {
            d->shown = true;
            for (int id : d->order) {
                QWidget *m = d->ctrls[id].main;
                if (m->focusPolicy() & Qt::TabFocus && m->isEnabled() && m->isVisible()) { m->setFocus(); break; }
            }
        }
        return "1";
    }
    if (name == "destroy") {
        Dlg *d = dialog(arg(0)); if (!d) return "0";
        dialogs.erase(d->key);
        d->win->hide();
        d->win->deleteLater();
        delete d;
        return "1";
    }
    if (name == "sub") {
        Dlg *d = dialog(arg(0)); if (d) d->subs.insert(arg(1) + "." + arg(2));
        return "1";
    }
    if (name == "screen") {
        const QRect s = QGuiApplication::primaryScreen()->geometry();
        return QString::number(s.width()) + " " + QString::number(s.height());
    }
    if (name == "measure") {
        const QFont f = dialogFont(arg(1), arg(2).isEmpty() ? 8 : arg(2).toDouble());
        double fx, fy;
        baseUnits(f, fx, fy);
        const QRect r = QFontMetrics(f).boundingRect(QRect(0, 0, 100000, 100000), Qt::AlignLeft | Qt::AlignTop, arg(0));
        return QString::number((int)std::ceil(r.width() / fx)) + " " + QString::number((int)std::ceil(r.height() / fy)) + " "
               + QString::number(r.width()) + " " + QString::number(r.height()) + " " + QString::number(fx) + " " + QString::number(fy);
    }
    if (name == "setMenu") {
        Dlg *d = dialog(arg(0)); if (!d) return "0";
        if (d->menuBar) { delete d->menuBar; d->menuBar = nullptr; }
        const QString data = payload.section(FS, 1);
        if (data.isEmpty()) return "1";
        d->menuBar = new QMenuBar(d->win);
        d->menuBar->setObjectName("ood-menubar");
        buildMenu(d, d->menuBar, data);
        static_cast<QVBoxLayout *>(d->win->layout())->setMenuBar(d->menuBar);
        return "1";
    }
    if (name == "msgBox") {                              // token, text, title, buttons, icon
        const QString token = arg(0), buttons = arg(3).toUpper(), icon = arg(4).toUpper();
        auto *m = new QMessageBox;
        m->setObjectName("ood-msgbox");
        m->setText(arg(1));
        m->setWindowTitle(arg(2));
        struct B { const char *word; QMessageBox::StandardButton b; int id; };
        static const B all[] = {{"ABORT", QMessageBox::Abort, 3}, {"RETRY", QMessageBox::Retry, 4}, {"IGNORE", QMessageBox::Ignore, 5},
                         {"YES", QMessageBox::Yes, 6}, {"NO", QMessageBox::No, 7}, {"OK", QMessageBox::Ok, 1}, {"CANCEL", QMessageBox::Cancel, 2}};
        QMessageBox::StandardButtons set;
        for (const B &b : all) if (buttons.contains(b.word)) set |= b.b;
        if (!set) set = QMessageBox::Ok;
        m->setStandardButtons(set);
        if (icon.contains("ERROR") || icon.contains("STOP") || icon.contains("HAND")) m->setIcon(QMessageBox::Critical);
        else if (icon.contains("QUESTION")) m->setIcon(QMessageBox::Question);
        else if (icon.contains("WARN") || icon.contains("EXCLAMATION")) m->setIcon(QMessageBox::Warning);
        else if (icon.contains("INFO") || icon.contains("ASTERISK")) m->setIcon(QMessageBox::Information);
        QObject::connect(m, &QMessageBox::finished, [m, token](int) {
            int id = 2;
            const auto clicked = m->standardButton(m->clickedButton());
            for (const B &b : all) if (b.b == clicked) id = b.id;
            fire(0, "MSGBOX", token, QString::number(id));
            m->deleteLater();
        });
        m->show();
        return "1";
    }
    if (name == "image") return "1";
    if (name == "hasImage") return "0";
    if (name == "popupMenu") {                           // token, x, y, data
        const QString token = arg(0);
        auto *menu = new QMenu;                          // the choice comes back as MSGBOX(token, id); 0 = none
        menu->setObjectName("ood-menu");
        auto chosen = std::make_shared<int>(0);
        for (const QString &r0 : payload.section(FS, 3).split(RS, Qt::SkipEmptyParts)) {
            const QStringList r = r0.split(FS);
            if (r.size() < 3 || r[0].toInt() != 0) continue;
            if ((" " + r.value(3) + " ").contains(" SEPARATOR ")) { menu->addSeparator(); continue; }
            QAction *act = menu->addAction(r[2]);
            const int id = r[1].toInt();
            QObject::connect(act, &QAction::triggered, [chosen, id] { *chosen = id; });
        }
        QObject::connect(menu, &QMenu::aboutToHide, [menu, token, chosen] {
            QTimer::singleShot(0, [menu, token, chosen] { fire(0, "MSGBOX", token, QString::number(*chosen)); menu->deleteLater(); });
        });
        menu->popup(QPoint(arg(1).toInt(), arg(2).toInt()));
        return "1";
    }
    if (name == "msg") {                                  // key, id, msg, wParam, lParam
        Dlg *d = dialog(arg(0)); if (!d) return "0";
        auto it = d->ctrls.find(arg(1).toInt()); if (it == d->ctrls.end()) return "0";
        Ctl &c = it->second;
        const int msg = arg(2).toInt(), w = arg(3).toInt(), l = arg(4).toInt();
        if (auto *b = qobject_cast<QAbstractButton *>(c.main)) {
            auto *cb = qobject_cast<QCheckBox *>(b);
            switch (msg) {
            case 0xF5: b->click(); return "0";
            case 0xF0: if (cb && cb->isTristate()) return QString::number(cb->checkState() == Qt::PartiallyChecked ? 2 : cb->isChecked() ? 1 : 0);
                       return b->isChecked() ? "1" : "0";
            case 0xF1: if (cb && cb->isTristate()) cb->setCheckState(w == 2 ? Qt::PartiallyChecked : w == 1 ? Qt::Checked : Qt::Unchecked);
                       else b->setChecked(w == 1);
                       return "0";
            case 0xF2: return QString::number((b->isChecked() ? 1 : 0) | (b->hasFocus() ? 8 : 0));
            }
        }
        if (auto *e = qobject_cast<QLineEdit *>(c.main)) {
            switch (msg) {
            case 0xB1: e->setSelection(w, (l < 0 ? e->text().size() : l) - w); return "1";
            case 0xB8: return c.modified ? "1" : "0";
            case 0xB9: c.modified = w != 0; return "0";
            case 0xBA: return "1";
            case 0xC5: e->setMaxLength(w > 0 ? w : 32767); return "0";
            case 0xCC: e->setEchoMode(w == 0 ? QLineEdit::Normal : QLineEdit::Password); return "0";
            case 0xD2: return e->echoMode() == QLineEdit::Password ? "42" : "0";
            case 0xCF: e->setReadOnly(w != 0); return "1";
            case 0x303: e->del(); return "0";
            }
        }
        if (auto *t = qobject_cast<QPlainTextEdit *>(c.main)) {
            switch (msg) {
            case 0xB8: return c.modified ? "1" : "0";
            case 0xB9: c.modified = w != 0; return "0";
            case 0xBA: return QString::number(t->blockCount());
            case 0xCF: t->setReadOnly(w != 0); return "1";
            }
        }
        if (auto *lw = qobject_cast<QListWidget *>(c.main)) {
            switch (msg) {
            case 0x182: if (w < 0 || w >= lw->count()) return "-1"; delete lw->takeItem(w); return QString::number(lw->count());
            case 0x184: lw->clear(); return "0";
            case 0x185: if (l < 0) { for (int i = 0; i < lw->count(); ++i) lw->item(i)->setSelected(w != 0); }
                        else if (lw->item(l)) lw->item(l)->setSelected(w != 0);
                        return "0";
            case 0x186: lw->setCurrentRow(w); return QString::number(lw->currentRow());
            case 0x187: return lw->item(w) && lw->item(w)->isSelected() ? "1" : "0";
            case 0x188: return QString::number(lw->currentRow());
            case 0x18B: return QString::number(lw->count());
            case 0x190: return QString::number(lw->selectedItems().size());
            case 0x18E: return "0";
            }
        }
        if (auto *cb = qobject_cast<QComboBox *>(c.main)) {
            switch (msg) {
            case 0x144: if (w < 0 || w >= cb->count()) return "-1"; cb->removeItem(w); return QString::number(cb->count());
            case 0x146: return QString::number(cb->count());
            case 0x147: return QString::number(cb->currentIndex());
            case 0x14B: cb->clear(); if (cb->isEditable()) cb->setEditText(""); return "0";
            case 0x14E: cb->setCurrentIndex(w); return QString::number(cb->currentIndex());
            case 0x14F: if (w) cb->showPopup(); return "1";
            case 0x157: return "0";
            }
        }
        if (auto *p = qobject_cast<QProgressBar *>(c.main)) {
            switch (msg) {
            case 0x402: { const int old = p->value(); p->setValue(w); return QString::number(old); }   // PBM_SETPOS
            case 0x408: return QString::number(p->value());                                         // PBM_GETPOS
            }
        }
        return "0";
    }
    if (name == "op") {                                   // key, id, name, a, b, c
        Dlg *d = dialog(arg(0)); if (!d) return "";
        const int id = arg(1).toInt();
        const QString op = arg(2), oa = arg(3), ob = arg(4);
        Ctl *c = nullptr;
        if (id != 0) {
            auto it = d->ctrls.find(id);
            if (it == d->ctrls.end()) return op == "exists" ? "0" : "";
            c = &it->second;
        }
        QWidget *el = c ? c->el : (QWidget *)d->win, *m = c ? c->main : (QWidget *)d->win;
        if (op == "exists") return "1";
        if (op == "kind") return c ? c->kind : "DIALOG";
        if (op == "getText") {
            if (!c) return d->win->windowTitle();
            if (auto *e = qobject_cast<QLineEdit *>(m)) return e->text();
            if (auto *t = qobject_cast<QPlainTextEdit *>(m)) return t->toPlainText().replace("\n", "\r\n");
            if (auto *cb = qobject_cast<QComboBox *>(m)) return cb->currentText();
            if (auto *lw = qobject_cast<QListWidget *>(m)) return lw->currentItem() ? lw->currentItem()->text() : "";
            return c->rawText;
        }
        if (op == "setText") {
            if (!c) { d->win->setWindowTitle(oa); return "1"; }
            if (auto *e = qobject_cast<QLineEdit *>(m)) { e->setText(oa); return "1"; }
            if (auto *t = qobject_cast<QPlainTextEdit *>(m)) { t->setPlainText(QString(oa).replace("\r\n", "\n")); return "1"; }
            if (auto *cb = qobject_cast<QComboBox *>(m)) { if (cb->isEditable()) cb->setEditText(oa); return "1"; }
            c->rawText = oa;
            if (auto *l = qobject_cast<QLabel *>(m)) l->setText(plain(oa));
            else if (auto *b = qobject_cast<QAbstractButton *>(m)) b->setText(oa);
            else if (auto *g = qobject_cast<QGroupBox *>(m)) g->setTitle(plain(oa));
            return "1";
        }
        if (op == "show") { el->show(); return "1"; }
        if (op == "hide") { el->hide(); return "1"; }
        if (op == "isVisible") return el->isVisibleTo(el->parentWidget() ? el->parentWidget() : el) && !el->isHidden() ? "1" : "0";
        if (op == "enable") { m->setEnabled(oa != "0"); return "1"; }
        if (op == "isEnabled") return m->isEnabled() ? "1" : "0";
        if (op == "focus") { m->setFocus(); return "1"; }
        if (op == "focusId") {
            QWidget *f = d->win->focusWidget();
            for (int cid : d->order) if (d->ctrls[cid].main == f) return QString::number(cid);
            return "0";
        }
        if (op == "rect") { const QRect r(el->mapToGlobal(QPoint(0, 0)), el->size()); return QString("%1 %2 %3 %4").arg(r.left()).arg(r.top()).arg(r.right() + 1).arg(r.bottom() + 1); }
        if (op == "clientRect") { QWidget *w = c ? el : d->client; return QString("0 0 %1 %2").arg(w->width()).arg(w->height()); }
        if (op == "origin") { const QPoint p = d->client->mapToGlobal(QPoint(0, 0)); return QString("%1 %2").arg(p.x()).arg(p.y()); }
        if (op == "move") { el->move(oa.toInt(), ob.toInt()); return "1"; }
        if (op == "size") { if (c) el->resize(oa.toInt(), ob.toInt()); else d->client->setFixedSize(oa.toInt(), ob.toInt()); return "1"; }
        if (op == "closeBox") { d->noClose = oa == "0"; return "1"; }
        if (op == "top") { d->win->raise(); return "1"; }
        if (op == "default") {
            if (auto old = d->ctrls.find(d->defId); old != d->ctrls.end()) if (auto *b = qobject_cast<QPushButton *>(old->second.main)) b->setDefault(false);
            d->defId = oa.toInt();
            if (auto nw = d->ctrls.find(d->defId); nw != d->ctrls.end()) if (auto *b = qobject_cast<QPushButton *>(nw->second.main)) b->setDefault(true);
            return "1";
        }
        if (op == "textSize") { const QSize s = QFontMetrics(m->font()).size(0, oa); return QString("%1 %2").arg(s.width()).arg(s.height()); }
        if (op == "sel") { if (auto *e = qobject_cast<QLineEdit *>(m)) { const int s = e->selectionStart() < 0 ? e->cursorPosition() : e->selectionStart(); return QString("%1 %2").arg(s + 1).arg(s + e->selectedText().size() + 1); } return "1 1"; }
        if (op == "replaceSel") { if (auto *e = qobject_cast<QLineEdit *>(m)) { e->insert(oa); c->modified = true; } return "1"; }
        if (op == "line") { if (auto *t = qobject_cast<QPlainTextEdit *>(m)) return t->toPlainText().split('\n').value(oa.toInt() - 1); if (auto *e = qobject_cast<QLineEdit *>(m)) return oa == "1" ? e->text() : ""; return ""; }
        if (op == "cue") { if (auto *e = qobject_cast<QLineEdit *>(m)) e->setPlaceholderText(oa); return "1"; }
        auto *lw = qobject_cast<QListWidget *>(m);
        auto *cb = qobject_cast<QComboBox *>(m);
        if (op == "add" || op == "insert") {
            const QString text = op == "add" ? oa : ob;
            const int at = op == "add" ? -1 : oa.toInt();
            if (lw) { if (at < 0 || at >= lw->count()) { lw->addItem(text); return QString::number(lw->row(lw->findItems(text, Qt::MatchExactly).value(0))); } lw->insertItem(at, text); return QString::number(at); }
            if (cb) { if (at < 0 || at >= cb->count()) { cb->addItem(text); return QString::number(cb->findText(text)); } cb->insertItem(at, text); return QString::number(at); }
            return "-1";
        }
        if (op == "itemText") { const int i = oa.toInt(); if (lw) return lw->item(i) ? lw->item(i)->text() : ""; if (cb) return cb->itemText(i); return ""; }
        if (op == "find") {
            const bool exact = arg(5) == "1";
            const int start = ob.toInt();
            const int n = lw ? lw->count() : cb ? cb->count() : 0;
            for (int k = 1; k <= n; ++k) {
                const int i = (start + k + n) % n;
                const QString t = lw ? lw->item(i)->text() : cb->itemText(i);
                if (exact ? t.compare(oa, Qt::CaseInsensitive) == 0 : t.startsWith(oa, Qt::CaseInsensitive)) return QString::number(i);
            }
            return "-1";
        }
        if (op == "selItems") {
            QStringList out;
            if (lw) for (int i = 0; i < lw->count(); ++i) if (lw->item(i)->isSelected()) out << QString::number(i + 1);
            return out.join(' ');
        }
        if (op == "selectText") {
            if (lw) { auto items = lw->findItems(oa, Qt::MatchStartsWith); const int i = items.isEmpty() ? -1 : lw->row(items[0]); lw->setCurrentRow(i); return QString::number(i); }
            if (cb) { const int i = cb->findText(oa, Qt::MatchStartsWith); if (i >= 0) cb->setCurrentIndex(i); else if (cb->isEditable()) cb->setEditText(oa); return QString::number(i); }
            return "-1";
        }
        fprintf(stderr, "oodqt: op not implemented yet: %s\n", qPrintable(op));
        return "";
    }
    fprintf(stderr, "oodqt: message not implemented yet: %s\n", qPrintable(name));
    return "";
}

/*======================================================================*/
/* Steps player: the browser harness's .steps files, against Qt widgets */
/*======================================================================*/
struct Steps {
    QStringList lines;
    int at = 0;
    QElapsedTimer since;
    qint64 sleepUntil = -1;
    QString shots;
    QTimer timer;
} *steps = nullptr;

QWidget *topDialog() {
    QWidget *best = nullptr;
    for (auto &kv : dialogs) if (kv.second->win->isVisible()) best = kv.second->win;   // the newest visible one
    if (QWidget *m = QApplication::activeModalWidget()) if (m->objectName() == "ood-msgbox") return m;
    return best;
}

QString widgetText(QWidget *w) {
    if (auto *b = qobject_cast<QAbstractButton *>(w)) return plain(b->text());
    if (auto *l = qobject_cast<QLabel *>(w)) return l->text();
    if (auto *g = qobject_cast<QGroupBox *>(w)) return g->title();
    return QString();
}

/* Selectors used by the .steps files:
 *   SCOPE >> text=TEXT    SCOPE input[.ood-edit]   SCOPE .ood-check input   SCOPE textarea   SCOPE select
 * SCOPE is .ood-dlg (the newest visible dialog), .ood-menubar or .ood-menu. */
QObject *find(const QString &selector, QString *why) {
    QString sel = selector.trimmed();
    QString scope = sel.section(' ', 0, 0);
    QString rest = sel.section(' ', 1).trimmed();
    if (scope != ".ood-dlg" && scope != ".ood-menubar" && scope != ".ood-menu") { rest = sel; scope = ".ood-dlg"; }
    if (rest.startsWith(">>")) rest = rest.mid(2).trimmed();
    QWidget *root = topDialog();
    if (scope == ".ood-menubar") {
        if (!root) { *why = "no dialog"; return nullptr; }
        auto *bar = root->findChild<QMenuBar *>("ood-menubar");
        if (!bar) { *why = "no menu bar"; return nullptr; }
        if (rest.startsWith("text=")) for (QAction *a : bar->actions()) if (plain(a->text()) == rest.mid(5)) return a;
        *why = "no menu bar item " + rest; return nullptr;
    }
    if (scope == ".ood-menu") {
        for (QWidget *w : QApplication::topLevelWidgets()) if (auto *m = qobject_cast<QMenu *>(w)) if (m->isVisible())
            if (rest.startsWith("text=")) for (QAction *a : m->actions()) if (plain(a->text()) == rest.mid(5)) return a;
        *why = "no open menu item " + rest; return nullptr;
    }
    if (!root) { *why = "no visible dialog"; return nullptr; }
    if (rest.startsWith("text=")) {
        const QString want = rest.mid(5);
        for (QWidget *w : root->findChildren<QWidget *>()) if (w->isVisible() && widgetText(w) == want) return w;
        *why = "no visible widget with text " + want; return nullptr;
    }
    QList<QWidget *> cands;
    if (rest.startsWith("input") && !rest.contains("ood-check")) for (auto *e : root->findChildren<QLineEdit *>()) cands << e;
    else if (rest.contains(".ood-check")) for (auto *b : root->findChildren<QAbstractButton *>()) { if (qobject_cast<QCheckBox *>(b) || qobject_cast<QRadioButton *>(b)) cands << b; }
    else if (rest.startsWith("textarea")) for (auto *t : root->findChildren<QPlainTextEdit *>()) cands << t;
    else if (rest.startsWith("select")) { for (auto *c : root->findChildren<QComboBox *>()) cands << c; for (auto *l : root->findChildren<QListWidget *>()) cands << l; }
    for (QWidget *w : cands) if (w->isVisible()) return w;
    *why = "nothing matches " + rest; return nullptr;
}

void stepFailed(const QString &line, const QString &why) {
    fflush(stdout);
    fprintf(stderr, "oodqt: STEP FAILED: %s (%s)\n", qPrintable(line), qPrintable(why));
    fflush(stderr);
    std::_Exit(3);
}

void stepTick() {
    if (!steps || steps->at >= steps->lines.size()) { if (steps) steps->timer.stop(); return; }
    if (steps->sleepUntil >= 0) {
        if (steps->since.elapsed() < steps->sleepUntil) return;
        steps->sleepUntil = -1; steps->at++; steps->since.restart(); return;
    }
    const QString line = steps->lines[steps->at].trimmed();
    if (line.isEmpty() || line.startsWith('#')) { steps->at++; return; }
    const QString verb = line.section(' ', 0, 0), rest = line.section(' ', 1);
    QString why;
    auto done = [&] { fprintf(stderr, "oodqt: step %d ok: %s\n", steps->at + 1, qPrintable(line)); steps->at++; steps->since.restart(); };
    if (verb == "sleep") { steps->sleepUntil = rest.toInt(); steps->since.restart(); return; }
    if (verb == "shot") {
        if (QWidget *w = topDialog()) if (!steps->shots.isEmpty()) w->grab().save(steps->shots + "/" + rest.trimmed() + ".png");
        done(); return;
    }
    if (verb == "wait" || verb == "click" || verb == "fill" || verb == "select") {
        QString sel = rest, value;
        if (verb == "fill" || verb == "select") { sel = rest.section(" => ", 0, 0); value = rest.section(" => ", 1); }
        QObject *o = find(sel, &why);
        if (!o) { if (steps->since.elapsed() > 10000) stepFailed(line, why); return; }
        if (verb == "click") {
            if (auto *a = qobject_cast<QAction *>(o)) {
                if (a->menu()) {
                    auto *bar = topDialog()->findChild<QMenuBar *>("ood-menubar");
                    a->menu()->popup(bar ? bar->mapToGlobal(bar->actionGeometry(a).bottomLeft()) : QPoint(0, 0));
                } else {
                    a->trigger();
                    for (QWidget *w : QApplication::topLevelWidgets()) if (auto *m = qobject_cast<QMenu *>(w)) m->hide();
                }
            }
            else if (auto *b = qobject_cast<QAbstractButton *>(o)) b->click();
            else if (auto *w = qobject_cast<QWidget *>(o)) { w->setFocus(); QMouseEvent p(QEvent::MouseButtonRelease, QPointF(2, 2), QPointF(2, 2), Qt::LeftButton, Qt::NoButton, Qt::NoModifier); QApplication::sendEvent(w, &p); }
        }
        if (verb == "fill") {
            if (auto *e = qobject_cast<QLineEdit *>(o)) { e->setFocus(); e->selectAll(); e->insert(value); }
            else if (auto *t = qobject_cast<QPlainTextEdit *>(o)) { t->setFocus(); t->setPlainText(value); }
            for (auto &kv : dialogs) for (auto &cc : kv.second->ctrls) if (cc.second.main == o) cc.second.modified = true;
        }
        if (verb == "select") {
            if (auto *c = qobject_cast<QComboBox *>(o)) { const int i = c->findText(value); c->setCurrentIndex(i); emit c->activated(i); }
            if (auto *l = qobject_cast<QListWidget *>(o)) { auto f = l->findItems(value, Qt::MatchExactly); if (!f.isEmpty()) l->setCurrentItem(f[0]); }
        }
        done(); return;
    }
    if (verb == "press") {
        const QString k = rest.trimmed();
        int key = k == "Enter" ? Qt::Key_Return : k == "Escape" ? Qt::Key_Escape : k == "Tab" ? Qt::Key_Tab : k == "F1" ? Qt::Key_F1 : k.size() == 1 ? k[0].toUpper().unicode() : 0;
        QWidget *target = QApplication::focusWidget() ? QApplication::focusWidget() : topDialog();
        if (!target || !key) stepFailed(line, "no focus or unknown key");
        QKeyEvent dn(QEvent::KeyPress, key, Qt::NoModifier, k.size() == 1 ? k : QString());
        QApplication::sendEvent(target, &dn);
        done(); return;
    }
    stepFailed(line, "this step is not supported by the Qt player (" + verb + ")");
}

void ensureApp() {
    if (app) return;
    static int argc = 1;
    static char name[] = "oodqt";
    static char *argv[] = {name, nullptr};
    app = new QApplication(argc, argv);
    app->setQuitOnLastWindowClosed(false);
    const QByteArray file = qgetenv("OODQT_STEPS");
    if (!file.isEmpty()) {
        QFile f(QString::fromLocal8Bit(file));
        if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            steps = new Steps;
            steps->lines = QTextStream(&f).readAll().split('\n');
            steps->shots = QString::fromLocal8Bit(qgetenv("OODQT_SHOTS"));
            steps->since.start();
            QObject::connect(&steps->timer, &QTimer::timeout, stepTick);
            steps->timer.start(50);
        }
    }
}

}  // namespace

RexxRoutine2(RexxStringObject, oodqt_call, CSTRING, name, RexxStringObject, payload)
{
    ensureApp();
    const QString p = QString::fromUtf8(context->StringData(payload), (int)context->StringLength(payload));
    const QByteArray out = call(QString::fromUtf8(name), p).toUtf8();
    return context->NewString(out.constData(), out.size());
}

RexxRoutine1(RexxStringObject, oodqt_next, int, ms)
{
    ensureApp();
    if (events.empty()) {
        QEventLoop loop;
        QTimer::singleShot(std::max(0, ms), &loop, &QEventLoop::quit);
        waiting = &loop;
        loop.exec();
        waiting = nullptr;
        app->sendPostedEvents(nullptr, QEvent::DeferredDelete);
    }
    if (events.empty()) return context->NullString();
    const QByteArray out = events.front().toUtf8();
    events.pop_front();
    return context->NewString(out.constData(), out.size());
}

RexxRoutineEntry oodqt_routines[] = {
    REXX_TYPED_ROUTINE(oodqt_call, oodqt_call),
    REXX_TYPED_ROUTINE(oodqt_next, oodqt_next),
    REXX_LAST_ROUTINE()
};

RexxPackageEntry oodqt_package_entry = {
    STANDARD_PACKAGE_HEADER
    REXX_INTERPRETER_5_0_0,
    "oodqt",
    "0.1.0",
    NULL,
    NULL,
    oodqt_routines,
    NULL
};

OOREXX_GET_PACKAGE(oodqt);
