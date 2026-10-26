package session

import "context"

func (s *Session) profileAssets(ctx context.Context) (string, *ActionResult) {
	if result := s.requireOnline(); result != nil {
		return "", result
	}
	if err := s.webProfile.Validate(); err != nil || !s.target.Local || s.target.ConfigPath == "" {
		result := rejected("profile_forbidden", "Web UI profiles require an authorized local Syncthing configuration")
		return "", &result
	}
	paths, err := s.client.SystemPaths(ctx)
	if err != nil || paths.GUIAssets == "" || paths.GUIAssets != s.Current().State.WebUI.GUIAssets {
		result := rejected("profile_target_changed", "Syncthing's GUI asset directory changed or is unavailable; refresh first")
		return "", &result
	}
	return paths.GUIAssets, nil
}

func (s *Session) applyWebProfile(ctx context.Context, args ActionArguments) ActionResult {
	assets, failure := s.profileAssets(ctx)
	if failure != nil {
		return *failure
	}
	name, err := s.webProfile.Prepare(assets, args.Profile, args.Palette)
	if err != nil {
		return rejected("profile_prepare", err.Error())
	}
	return s.setWebUITheme(ctx, name)
}

func (s *Session) removeWebProfile(ctx context.Context) ActionResult {
	assets, failure := s.profileAssets(ctx)
	if failure != nil {
		return *failure
	}
	current, err := s.client.GUIConfig(ctx)
	if err != nil {
		return ActionResult{Error: publicError(err)}
	}
	modern, _ := s.webProfile.Name("modern")
	themed, _ := s.webProfile.Name("themed")
	if current.Theme != "default" && current.Theme != modern && current.Theme != themed {
		return rejected("profile_not_selected", "Another Web UI profile is selected; switch to default before removing this adapter's profiles")
	}
	if result := s.setWebUITheme(ctx, "default"); !result.OK {
		return result
	}
	if err := s.webProfile.Remove(assets); err != nil {
		return rejected("profile_cleanup", err.Error())
	}
	return s.refreshAfterMutation(ctx)
}
