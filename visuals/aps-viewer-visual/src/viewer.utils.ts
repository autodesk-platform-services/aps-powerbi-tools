/// import * as Autodesk from "@types/forge-viewer";

'use strict';

const runtime: { options: Autodesk.Viewing.InitializerOptions; ready: Promise<void> | null } = {
    options: {},
    ready: null
};

export function initializeViewerRuntime(options: Autodesk.Viewing.InitializerOptions): Promise<void> {
    if (!runtime.ready) {
        runtime.options = { ...options };
        runtime.ready = (async function () {
            await loadScript('https://developer.api.autodesk.com/modelderivative/v2/viewers/7.*/viewer3D.js');
            await loadStylesheet('https://developer.api.autodesk.com/modelderivative/v2/viewers/7.*/style.css');
            return new Promise((resolve, reject) => Autodesk.Viewing.Initializer(runtime.options, resolve));
        })();
    } else {
        if (['accessToken', 'getAccessToken', 'env', 'api', 'language'].some(prop => options[prop] !== runtime.options[prop])) {
            return Promise.reject('Cannot initialize another viewer runtime with different settings.');
        }
    }
    return runtime.ready;
}

export function loadModel(viewer: Autodesk.Viewing.Viewer3D, urn: string, guid?: string): Promise<Autodesk.Viewing.Model> {
    return new Promise(function (resolve, reject) {
        Autodesk.Viewing.Document.load(
            'urn:' + urn,
            (doc) => {
                const view = guid ? doc.getRoot().findByGuid(guid) : doc.getRoot().getDefaultGeometry();
                viewer.loadDocumentNode(doc, view).then(m => resolve(m));
            },
            (code, message, args) => reject({ code, message, args })
        );
    });
}

export function getVisibleNodes(model: Autodesk.Viewing.Model): number[] {
    const tree = model.getInstanceTree();
    const dbids: number[] = [];
    tree.enumNodeChildren(tree.getRootId(), dbid => {
        if (tree.getChildCount(dbid) === 0 && !tree.isNodeHidden(dbid) && !tree.isNodeOff(dbid)) {
            dbids.push(dbid);
        }
    }, true);
    return dbids;
}

export function getExternalIdMap(model: Autodesk.Viewing.Model): Promise<{ [externalId: string]: number; }> {
    return new Promise(function (resolve, reject) {
        model.getExternalIdMapping(resolve, reject);
    });
}

export function getExternalIds(model: Autodesk.Viewing.Model, dbids: number[]): Promise<string[]> {
    return new Promise(function (resolve, reject) {
        model.getBulkProperties(dbids, { propFilter: ['externalId'] }, results => {
            resolve(results.map(result => result.externalId))
        }, reject);
    });
}

function loadScript(src: string): Promise<void> {
    return new Promise((resolve, reject) => {
        const el = document.createElement("script");
        el.onload = () => resolve();
        el.onerror = (err) => reject(err);
        el.type = 'application/javascript';
        el.src = src;
        document.head.appendChild(el);
    });
}

function loadStylesheet(href: string): Promise<void> {
    return new Promise((resolve, reject) => {
        const el = document.createElement('link');
        el.onload = () => resolve();
        el.onerror = (err) => reject(err);
        el.rel = 'stylesheet';
        el.href = href;
        document.head.appendChild(el);
    });
}
