using Toybox.Application as App;

class GraphicalHeartRateApp extends App.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        return false;
    }

    function getInitialView() {
        return [new GraphicalHeartRateView()];
    }

    function onStop(state) {
        return false;
    }
}