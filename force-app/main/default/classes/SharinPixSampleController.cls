public with sharing class SharinPixSampleController {
    public string parameters {get;set;}

    public SharinPixSampleController(ApexPages.standardController controller) {
        Id id = controller.getId();

        map<string, boolean> access = new map<string, boolean>();
        access.put('see', true);
        access.put('image_list', true);
        access.put('image_upload', true);
        access.put('image_delete', true);
        access.put('image_crop', true);
        access.put('image_rotate', true);

        map<string, object> album_abilities = new map<string, object>();
        album_abilities.put('Access', access);

        map<string, object> abilities = new map<string, object>();
        abilities.put(id, album_abilities);

        map<string, object> params = new map<string, object>();
        params.put('abilities', abilities);

        params.put('Id', id);
        parameters = JSON.serialize(params);
    }
}