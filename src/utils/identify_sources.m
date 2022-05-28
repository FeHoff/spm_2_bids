function sources = identify_sources(varargin)
    %
    % finds the most likely files in the detrivatives that was used to create
    % this file
    %
    % USAGE::
    %
    %   sources = identify_sources(derivatives, map, verbose)
    %
    % :param derivatives: derivatives file whose source to identify
    % :type derivatives: string
    %
    % :param map: a mapping object. See ``Mapping`` class and or function ``default_mapping``
    % :type map: object
    %
    % :param verbose: Defaults to ``true``
    % :type verbose: boolean
    %
    % (C) Copyright 2021 spm_2_bids developers

    % "r" could mean realigned or resliced...
    %     'sr'
    %     'sra'
    %     'wr'
    %     'wra'
    % those will throw warnings

    % TODO
    % functional to anatomical coregistration
    % anatomical to functional coregistration

    default_map = Mapping();
    default_map = default_map.default();

    sources = '';

    prefix_based = true;

    add_deformation_field = false;
    deformation_field = 'TODO: add deformation field';

    args = inputParser;

    addOptional(args, 'derivatives', pwd, @ischar);
    addOptional(args, 'map', default_map);
    addOptional(args, 'verbose', true, @islogical);

    parse(args, varargin{:});

    derivatives = args.Results.derivatives;
    map = args.Results.map;
    verbose = args.Results.verbose;

    if isempty(derivatives)
        return
    end

    % deal with SPM's funky suffixes
    if endsWith(derivatives, '_seg8.mat')

        prefix_based = false;

        derivatives = strrep(derivatives, '_seg8.mat', '.nii');

    elseif endsWith(derivatives, '_uw.mat')

        prefix_based = false;

        derivatives = strrep(derivatives, '_uw.mat', '.nii');

    end

    bf = bids.File(derivatives, 'verbose', verbose, 'use_schema', false);

    if ~ismember(bf.suffix, fieldnames(map.cfg.schema.content.objects.suffixes))
        sources{1} = 'TODO';
        return
    end

    % deal with surface data
    if strcmp(bf.extension, '.surf.gii')
        bf.extension = '.nii';
        prefix_based = false;
    end

    % unless this file already contains a derivative entity
    % it needs at least 2 characters for this file
    % to have some provenance in the derivatives
    if length(bf.prefix) == 1 && any(ismember(fieldnames(bf.entities), map.cfg.entity_order))
        bf.prefix = '';
        sources{1, 1} = fullfile(bf.bids_path, bf.filename);
        return
    end

    % anything prefix based
    if prefix_based

        if length(bf.prefix) < 2

            % TODO: files that have been realigned but not resliced have no
            % "prefix" so we may miss some transformation
            return

        end

        % remove the prefix of the last step
        if startsWith(bf.prefix, 's')

            % in case the prefix includes a number to denotate the FXHM used
            % for smoothing
            starts_with_fwhm = regexp(bf.prefix, '^s[0-9]*', 'match');
            if ~isempty(starts_with_fwhm)
                bf = shorten_prefix(bf, length(starts_with_fwhm{1}));
            else
                bf = shorten_prefix(bf, 1);
            end

        elseif startsWith(bf.prefix, 'u')
            bf = shorten_prefix(bf, 1);

        elseif startsWith(bf.prefix, 'w')
            bf = shorten_prefix(bf, 1);
            add_deformation_field = true;

        elseif startsWith(bf.prefix, 'rp_a')
            bf = shorten_prefix(bf, 3);

        elseif startsWith(bf.prefix, 'mean')
            % TODO mean may involve several files from the source (across runs
            % and sessions
            %     prefixes = {
            %                 'mean'
            %                 'meanu'
            %                 'meanua'
            %                };
            sources = 'TODO';
            return

        elseif ismember(bf.prefix(1:2), {'c1', 'c2', 'c3', 'c4', 'c5'})
            % bias corrected image
            sources = 'TODO';
            return

        else
            % no idea
            sources = 'TODO';
            return

        end

    end

    % call spm_2_bids what is the filename from the previous step
    new_filename = spm_2_bids(bf.filename, map, verbose);

    sources{1, 1} = fullfile(bf.bids_path, new_filename);

    % for normalized images
    if add_deformation_field

        % for anatomical data we assume that
        % the deformation field comes from the anatomical file itself
        if (~isempty(bf.modality) && ismember(bf.modality, {'anat'})) || ...
            (~isempty(bf.suffix) && ~isempty(map.cfg.schema.find_suffix_group('anat', bf.suffix)))

            bf.prefix = 'y_';
            bf = bf.update;
            new_filename = spm_2_bids(bf.filename, map, verbose);
            deformation_field = fullfile(bf.bids_path, new_filename);

            % otherwise we can't guess it just from the file name
        else

        end

        sources{2, 1} = deformation_field;

    end

end

function bf = shorten_prefix(bf, len)
    bf.prefix = bf.prefix((len + 1):end);
end
