import QtQuick
import QtTest
import "../../" as App

TestCase {
    id: root
    name: "ProfileService"
    property var service: null
    Component { id: factory; App.Service {} }
    SignalSpy { id: closed; target: root.service; signalName: "closeApproved" }

    function init() {
        root.service = factory.createObject(root);
        verify(root.service !== null);
        closed.clear();
    }
    function cleanup() { root.service.destroy(); root.service = null; }
    function draft() {
        service.dispatch({kind:"new"});
        service.dispatch({kind:"draft",change:{kind:"name",value:"My profile"}});
        service.dispatch({kind:"draft",change:{kind:"include",side:"output",value:true}});
    }
    function test_cancel_preserves_real_service_device_volume_mute() {
        draft();
        service.eqChange("output","gain",7.5,1);
        compare(service.effective.output.eq.gains[1],7.5);
        service.change("output","device",0,0);
        service.change("output","volume",23,0);
        service.change("output","mute",0,0);
        service.setStreamVolume(0,19);
        service.dispatch({kind:"cancel"});
        compare(service.effective.output.eq.gains[1],0);
        compare(service.state.output.device,1);
        compare(service.state.output.volume,23);
        compare(service.state.output.muted,true);
        compare(service.state.streams[0].volume,19);
    }
    function test_dirty_close_requires_resolution() {
        draft();
        service.dispatch({kind:"close"});
        compare(closed.count,0);
        compare(service.profileState.pendingAction.kind,"close");
        service.dispatch({kind:"resolve",choice:"keep"});
        verify(service.profileState.session !== null);
        service.dispatch({kind:"close"});
        service.dispatch({kind:"resolve",choice:"discard"});
        compare(closed.count,1);
        compare(service.profileState.session,null);
    }
    function test_saved_latest_draft_survives_ui_close_only() {
        draft();
        service.eqChange("output","gain",11.5,9);
        service.dispatch({kind:"save"});
        compare(service.profileState.profiles.length,3);
        compare(service.profileState.profiles[2].output.gains[9],11.5);
        verify(service.profileState.profiles[2].input === undefined);
        service.dispatch({kind:"close"});
        compare(closed.count,1);
        compare(service.profileState.profiles.length,3);
    }
    function test_independent_origins_and_inclusion() {
        service.dispatch({kind:"apply",id:"factory-fixture-gaming"});
        service.dispatch({kind:"apply",id:"factory-fixture-music"});
        compare(service.sideLabel("input"),"Fixture Gaming");
        compare(service.sideLabel("output"),"Fixture Music");
        compare(service.effective.input.eq.gains[4],2);
        compare(service.effective.output.eq.gains[7],-2);
        service.dispatch({kind:"new"});
        compare(service.profileState.session.included.input,false);
        compare(service.profileState.session.included.output,false);
        compare(service.effective.input.eq.gains[4],2);
    }
    function test_failed_save_keeps_dirty_editor_and_close_pending() {
        draft();
        const model = JSON.parse(JSON.stringify(service.profileState));
        model.failSave = true;
        service.profileState = model;
        service.dispatch({kind:"close"});
        service.dispatch({kind:"resolve",choice:"save"});
        compare(closed.count,0);
        compare(service.profileState.profiles.length,2);
        verify(service.profileState.session.dirty);
        verify(service.profileState.error.indexOf("Save failure") !== -1);
        service.dispatch({kind:"resolve",choice:"save"});
        compare(closed.count,1);
        compare(service.profileState.profiles.length,3);
    }
}
